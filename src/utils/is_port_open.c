#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdio.h>
#include <stdlib.h>

#define MMIO_SIZE 0x1000

static void spin_sleep()
{
    volatile uint64_t counter = 0;
    while (counter++ < 500000000)
        if(counter == 1ull << 35)
            perror("spinning for 1 << 35");
}

static bool is_udp_port_open(int port)
{
    FILE *f = fopen("/proc/net/udp", "r");
    if (!f) {
        perror("fopen /proc/net/udp");
        return false;
    }

    char port_str[8];
    snprintf(port_str, sizeof(port_str), ":%04X", port);

    char line[256];
    fgets(line, sizeof(line), f);

    while (fgets(line, sizeof(line), f)) {
        char local_addr[32];
        int sl;
        if (sscanf(line, "%d: %31s", &sl, local_addr) == 2) {
            if (strstr(local_addr, port_str)) {
                fclose(f);
                return true;
            }
        }
    }

    fclose(f);
    return false;
}

static void signal_ready(uintptr_t mmio_base)
{
    int fd = open("/dev/mem", O_RDWR);
    if (fd < 0) {
        perror("open /dev/mem");
        exit(1);
    }

    volatile uint32_t *reg = mmap(NULL, MMIO_SIZE,
                                  PROT_READ | PROT_WRITE, MAP_SHARED,
                                  fd, mmio_base);
    if (reg == MAP_FAILED) {
        perror("mmap failure");
        close(fd);
        exit(1);
    }

    *reg = 0;

    munmap((void *)reg, MMIO_SIZE);
    close(fd);
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s <port> <mmio_base>\n", argv[0]);
        return 1;
    }

    int port = atoi(argv[1]);
    uintptr_t mmio_base = strtoul(argv[2], NULL, 0);
    while (!is_udp_port_open(port)) spin_sleep();
    signal_ready(mmio_base);
    return 0;
}
