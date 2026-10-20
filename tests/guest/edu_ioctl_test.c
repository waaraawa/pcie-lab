#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define EDU_IOC_MAGIC 'e'
#define EDU_IOC_FACTORIAL _IOWR(EDU_IOC_MAGIC, 1, uint32_t)
#define EDU_IOC_DMA_TEST _IO(EDU_IOC_MAGIC, 2)

int main(void)
{
	int fd = open("/dev/edu0", O_RDWR);
	uint32_t val = 6;

	if (fd < 0)
		return 1;

	if (ioctl(fd, EDU_IOC_FACTORIAL, &val) < 0 || val != 720)
		return 2;

	printf("factorial(6) = %u\n", val);

	if (ioctl(fd, EDU_IOC_DMA_TEST) < 0)
		return 3;

	printf("DMA round-trip OK\n");

	val = 13;
	if (ioctl(fd, EDU_IOC_FACTORIAL, &val) != -1 || errno != EINVAL)
		return 4;

	if (ioctl(fd, EDU_IOC_FACTORIAL, NULL) != -1 || errno != EFAULT)
		return 5;

	printf("invalid input checks (EINVAL/EFAULT) OK\n");

	close(fd);
	return 0;
}
