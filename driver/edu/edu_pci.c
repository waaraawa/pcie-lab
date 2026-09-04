#include <linux/module.h>
#include <linux/pci.h>
#include <linux/io.h>
#include <linux/interrupt.h>
#include <linux/completion.h>
#include <linux/jiffies.h>
#include <linux/dma-mapping.h>

#define EDU_VENDOR_ID 0x1234
#define EDU_DEVICE_ID 0x11e8

#define EDU_REG_ID 0x00
#define EDU_REG_LIVENESS 0x04
#define EDU_REG_FACTORIAL 0x08
#define EDU_REG_STATUS 0x20
#define EDU_REG_IRQ_STATUS 0x24
#define EDU_REG_IRQ_RAISE 0x60
#define EDU_REG_IRQ_ACK 0x64

#define EDU_LIVENESS_TEST 0x12345678U

#define EDU_STATUS_COMPUTING 0x01U
#define EDU_STATUS_IRQFACT 0x80U

#define EDU_FACTORIAL_INPUT 5U
#define EDU_FACTORIAL_EXPECTED 120U

#define EDU_IRQ_FACTORIAL 0x01U

#define EDU_FACTORIAL_TIMEOUT_MS 1000

#define EDU_DMA_MASK_BITS 28
#define EDU_DMA_BUFFER_SIZE 64U

struct edu_device {
	struct pci_dev *pdev;
	void __iomem *bar0;
	void *dma_buf;
	dma_addr_t dma_addr;
	struct completion factorial_done;
	int irq;
};

static bool force_factorial_timeout;
module_param(force_factorial_timeout, bool, 0444);
MODULE_PARM_DESC(force_factorial_timeout,
		 "skip factorial start to exercise timeout cleanup");

static bool use_msi;
module_param(use_msi, bool, 0444);
MODULE_PARM_DESC(use_msi, "use MSI instead of legacy INTx");

static void edu_disable_factorial_irq(struct edu_device *edu)
{
	writel(0, edu->bar0 + EDU_REG_STATUS);
	writel(EDU_IRQ_FACTORIAL, edu->bar0 + EDU_REG_IRQ_ACK);

	readl(edu->bar0 + EDU_REG_IRQ_STATUS);
}

static irqreturn_t edu_irq_handler(int irq, void *data)
{
	struct edu_device *edu = data;
	struct pci_dev *pdev = edu->pdev;
	u32 pending;
	u32 remain;

	pending = readl(edu->bar0 + EDU_REG_IRQ_STATUS);
	if (!pending)
		return IRQ_NONE;

	writel(pending, edu->bar0 + EDU_REG_IRQ_ACK);

	remain = readl(edu->bar0 + EDU_REG_IRQ_STATUS);
	dev_info(&pdev->dev,
		 "irq: BDF=%s, irq=%d, pending=0x%08x remaining=0x%08x\n",
		 pci_name(pdev), irq, pending, remain);

	if (pending & EDU_IRQ_FACTORIAL)
		complete(&edu->factorial_done);

	return IRQ_HANDLED;
}

static int edu_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	int ret;
	void __iomem *bar0;
	u32 edu_id;
	u32 liveness;
	u32 status;
	u32 factorial;
	int irq;
	struct edu_device *edu;
	unsigned long timeout;
	unsigned int pci_irq_flags;
	unsigned long request_irq_flags;
	const char *irq_mode;

	edu = devm_kzalloc(&pdev->dev, sizeof(*edu), GFP_KERNEL);
	if (!edu)
		return -ENOMEM;

	edu->pdev = pdev;
	init_completion(&edu->factorial_done);

	dev_info(&pdev->dev,
		 "probe: BDF=%s vendor=0x%04x device=0x%04x irq=%u\n",
		 pci_name(pdev), id->vendor, id->device, pdev->irq);

	ret = pci_enable_device(pdev);
	if (ret) {
		dev_err(&pdev->dev, "failed to enable PCI device: %d\n", ret);
		return ret;
	}

	ret = dma_set_mask_and_coherent(&pdev->dev,
					DMA_BIT_MASK(EDU_DMA_MASK_BITS));
	if (ret) {
		dev_err(&pdev->dev, "failed to set %u-bit DMA mask: %d\n",
			EDU_DMA_MASK_BITS, ret);
		goto err_disable_device;
	}

	dev_info(&pdev->dev, "DMA mask: %u bits\n", EDU_DMA_MASK_BITS);

	ret = pci_request_region(pdev, 0, "edu_pci");
	if (ret) {
		dev_err(&pdev->dev, "failed to request BAR0: %d\n", ret);
		goto err_disable_device;
	}

	bar0 = pci_iomap(pdev, 0, 0);
	if (!bar0) {
		dev_err(&pdev->dev, "failed to map BAR0\n");
		ret = -ENOMEM;
		goto err_release_region;
	}

	edu->bar0 = bar0;

	edu_id = readl(bar0 + EDU_REG_ID);
	dev_info(&pdev->dev, "identification: 0x%08x\n", edu_id);

	writel(EDU_LIVENESS_TEST, bar0 + EDU_REG_LIVENESS);

	liveness = readl(bar0 + EDU_REG_LIVENESS);
	if (liveness != ~EDU_LIVENESS_TEST) {
		dev_err(&pdev->dev,
			"liveness mismatch: expected=0x%08x read=0x%08x\n",
			~EDU_LIVENESS_TEST, liveness);

		ret = -EIO;
		goto err_iounmap;
	}

	dev_info(&pdev->dev, "liveness: wrote=0x%08x read=0x%08x\n",
		 EDU_LIVENESS_TEST, liveness);

	edu->dma_buf = dma_alloc_coherent(&pdev->dev, EDU_DMA_BUFFER_SIZE,
					  &edu->dma_addr, GFP_KERNEL);
	if (!edu->dma_buf) {
		ret = -ENOMEM;
		goto err_iounmap;
	}

	dev_info(&pdev->dev, "DMA buffer: cpu=%p dma=%pad size=%u\n",
		 edu->dma_buf, &edu->dma_addr, EDU_DMA_BUFFER_SIZE);

	pci_set_master(pdev);

	pci_irq_flags = use_msi ? PCI_IRQ_MSI : PCI_IRQ_INTX;
	request_irq_flags = use_msi ? 0 : IRQF_SHARED;
	irq_mode = use_msi ? "MSI" : "INTx";

	pci_set_drvdata(pdev, edu);

	ret = pci_alloc_irq_vectors(pdev, 1, 1, pci_irq_flags);
	if (ret < 0) {
		dev_err(&pdev->dev, "failed to allocate %s vector: %d\n",
			irq_mode, ret);
		goto err_clear_drvdata;
	}

	irq = pci_irq_vector(pdev, 0);
	if (irq < 0) {
		ret = irq;
		dev_err(&pdev->dev, "failed to get IRQ vector: %d\n", irq);
		goto err_free_irq_vectors;
	}

	edu->irq = irq;

	ret = request_irq(irq, edu_irq_handler, request_irq_flags,
			  "edu_pci_irq", edu);
	if (ret) {
		dev_err(&pdev->dev, "failed to request IRQ %d: %d\n", irq, ret);
		goto err_free_irq_vectors;
	}

	dev_info(&pdev->dev, "interrupt mode: %s, irq=%d\n", irq_mode, irq);

	timeout = msecs_to_jiffies(EDU_FACTORIAL_TIMEOUT_MS);
	reinit_completion(&edu->factorial_done);

	writel(EDU_STATUS_IRQFACT, bar0 + EDU_REG_STATUS);

	if (force_factorial_timeout)
		dev_info(&pdev->dev, "forcing factorial timeout\n");
	else
		writel(EDU_FACTORIAL_INPUT, bar0 + EDU_REG_FACTORIAL);

	if (!wait_for_completion_timeout(&edu->factorial_done, timeout)) {
		status = readl(bar0 + EDU_REG_STATUS);
		dev_err(&pdev->dev, "factorial timeout: status=0x%08x\n",
			status);

		ret = -ETIMEDOUT;
		goto err_free_irq;
	}

	factorial = readl(bar0 + EDU_REG_FACTORIAL);
	dev_info(&pdev->dev, "factorial: %u! = %u\n", EDU_FACTORIAL_INPUT,
		 factorial);

	if (factorial != EDU_FACTORIAL_EXPECTED) {
		dev_err(&pdev->dev, "factorial mismatch: expected=%u read=%u\n",
			EDU_FACTORIAL_EXPECTED, factorial);
		ret = -EIO;
		goto err_free_irq;
	}

	edu_disable_factorial_irq(edu);
	return 0;

err_free_irq:
	edu_disable_factorial_irq(edu);
	free_irq(edu->irq, edu);
err_free_irq_vectors:
	pci_free_irq_vectors(pdev);
err_clear_drvdata:
	pci_set_drvdata(pdev, NULL);
	pci_clear_master(pdev);
	dma_free_coherent(&pdev->dev, EDU_DMA_BUFFER_SIZE, edu->dma_buf,
			  edu->dma_addr);
err_iounmap:
	pci_iounmap(pdev, bar0);
err_release_region:
	pci_release_region(pdev, 0);
err_disable_device:
	pci_disable_device(pdev);
	return ret;
}

static void edu_remove(struct pci_dev *pdev)
{
	struct edu_device *edu = pci_get_drvdata(pdev);
	void __iomem *bar0 = edu->bar0;

	dev_info(&pdev->dev, "remove: BDF=%s\n", pci_name(pdev));

	edu_disable_factorial_irq(edu);
	free_irq(edu->irq, edu);
	pci_free_irq_vectors(pdev);

	pci_set_drvdata(pdev, NULL);
	pci_clear_master(pdev);
	dma_free_coherent(&pdev->dev, EDU_DMA_BUFFER_SIZE, edu->dma_buf,
			  edu->dma_addr);

	pci_iounmap(pdev, bar0);
	pci_release_region(pdev, 0);
	pci_disable_device(pdev);
}

static const struct pci_device_id edu_pci_ids[] = {
	{ PCI_DEVICE(EDU_VENDOR_ID, EDU_DEVICE_ID) },
	{},
};

MODULE_DEVICE_TABLE(pci, edu_pci_ids);

static struct pci_driver edu_pci_driver = {
	.name = "edu_pci",
	.id_table = edu_pci_ids,
	.probe = edu_probe,
	.remove = edu_remove,
};

module_pci_driver(edu_pci_driver);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("minimal driver for the QEMU EDU PCI device");
