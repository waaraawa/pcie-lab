#include <linux/module.h>
#include <linux/pci.h>
#include <linux/io.h>
#include <linux/iopoll.h>
#include <linux/interrupt.h>
#include <linux/completion.h>

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

#define EDU_FACTORIAL_INPUT 5U
#define EDU_FACTORIAL_EXPECTED 120U

#define EDU_IRQ_TEST 0x01U

#define EDU_POLL_DELAY_US 10
#define EDU_POLL_TIMEOUT_US (1000 * 1000)

struct edu_device {
	struct pci_dev *pdev;
	void __iomem *bar0;
	struct completion factorial_done;
	int irq;
};

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
	dev_info(&pdev->dev, "liveness: wrote=0x%08x read=0x%08x\n",
		 EDU_LIVENESS_TEST, liveness);

	if (liveness != ~EDU_LIVENESS_TEST) {
		dev_err(&pdev->dev,
			"liveness mismatch: expected=0x%08x read=0x%08x\n",
			~EDU_LIVENESS_TEST, liveness);

		ret = -EIO;
		goto err_iounmap;
	}

	writel(EDU_FACTORIAL_INPUT, bar0 + EDU_REG_FACTORIAL);

	ret = readl_poll_timeout(bar0 + EDU_REG_STATUS, status,
				 !(status & EDU_STATUS_COMPUTING),
				 EDU_POLL_DELAY_US, EDU_POLL_TIMEOUT_US);
	if (ret) {
		dev_err(&pdev->dev, "factorial timeout: status=0x%08x\n",
			status);
		goto err_iounmap;
	}

	factorial = readl(bar0 + EDU_REG_FACTORIAL);
	dev_info(&pdev->dev, "factorial: %u! = %u\n", EDU_FACTORIAL_INPUT,
		 factorial);

	if (factorial != EDU_FACTORIAL_EXPECTED) {
		dev_err(&pdev->dev, "factorial mismatch: expected=%u read=%u\n",
			EDU_FACTORIAL_EXPECTED, factorial);
		ret = -EIO;
		goto err_iounmap;
	}

	pci_set_drvdata(pdev, edu);

	ret = pci_alloc_irq_vectors(pdev, 1, 1, PCI_IRQ_INTX);
	if (ret < 0) {
		dev_err(&pdev->dev, "failed to allocate INTx vector: %d\n",
			ret);
		goto err_clear_drvdata;
	}

	irq = pci_irq_vector(pdev, 0);
	if (irq < 0) {
		ret = irq;
		dev_err(&pdev->dev, "failed to get IRQ vector: %d\n", irq);
		goto err_free_irq_vectors;
	}

	edu->irq = irq;

	ret = request_irq(irq, edu_irq_handler, IRQF_SHARED, "edu_pci_irq",
			  edu);
	if (ret) {
		dev_err(&pdev->dev, "failed to request IRQ %d: %d\n", irq, ret);
		goto err_free_irq_vectors;
	}

	writel(EDU_IRQ_TEST, bar0 + EDU_REG_IRQ_RAISE);
	return 0;

err_free_irq_vectors:
	pci_free_irq_vectors(pdev);
err_clear_drvdata:
	pci_set_drvdata(pdev, NULL);
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

	free_irq(edu->irq, edu);
	pci_free_irq_vectors(pdev);

	pci_set_drvdata(pdev, NULL);

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
