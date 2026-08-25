#include <linux/init.h>
#include <linux/module.h>

static int __init phase0_sanity_init(void)
{
    pr_info("phase0_sanity: loaded\n");
    return 0;
}

static void __exit phase0_sanity_exit(void)
{
    pr_info("phase0_sanity: unloaded\n");
}

module_init(phase0_sanity_init);
module_exit(phase0_sanity_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("PCIe learning lab");
MODULE_DESCRIPTION("Phase 0 external-module build and load sanity check");
