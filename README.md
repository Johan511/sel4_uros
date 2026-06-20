# uros_sel4

[seL4](https://sel4.systems) is a formally verified L4 microkernel that can also act as a hypervisor, enabling a Linux virtual machine to run inside seL4. This project demonstrates porting micro-ROS applications out of the Linux VM into bare-metal seL4 protection domains (PDs).

A [blog post](https://johan511.github.io/posts/2025-01-19-uros-on-sel4/) provides additional background.

## Build instructions

### 1. One-time setup

```bash
./scripts/setup.sh
```

This script performs first-time initialization:
- Installs system packages via `apt-get`
- Downloads the `aarch64-none-elf` bare-metal GCC 12.2 toolchain for seL4 PDs
- Downloads the microkit SDK (default v2.2.0, override with `MICROKIT_VERSION`)
- Generates Linux VM guest images (kernel 5.18, Busybox 1.35 rootfs, device tree)
- Clones `libvmm` (with SDDF submodule) - AArch64 virtualization library
- Clones `musllibc` - seL4-adapted musl C library
- Cross-compiles the Micro-XRCE-DDS Agent v2.4.3 for the Linux guest with `aarch64-linux-gnu`
- Creates and configures the micro-ROS firmware workspace (`third_party/firmware`)

### 3. Build

```bash
mkdir -p build && pushd build && { cmake .. && make -j$(nproc); popd; }
```

Produces the final system image at `build/src/examples/ping_pong/loader.img`.

Key build artifacts:

| Artifact | Path |
|---|---|
| VMM protection domain | `build/src/vmm/vmm.elf` |
| ping_pong protection domain | `build/src/examples/ping_pong/ping_pong_component.elf` |
| Complete system image | `build/src/examples/ping_pong/loader.img` |

## Run

```bash
./scripts/run.sh ping_pong
```

Launches the system in QEMU (`qemu-system-aarch64`, `virt` machine, 3 Cortex-A53 CPUs, 2 GB RAM) with SLIRP user-mode networking. The ping_pong PD will start exchanging messages with the Micro-XRCE-DDS Agent inside the Linux VM guest.

To attach `gdb-multiarch`:

```bash
./scripts/run.sh ping_pong --debug
```

Set `BUILD_DIR` to use a different build directory:

```bash
BUILD_DIR=build_release ./scripts/run.sh ping_pong
```

## Dependencies

| Dependency | Version | Builds for | Purpose |
|---|---|---|---|
| `aarch64-none-elf` GCC | 12.2.rel1 | seL4 PDs | Bare-metal ARM64 cross-compiler |
| microkit SDK | 2.2.0 | seL4 | seL4 microkit runtime, linker script, build tool |
| libvmm | git HEAD | seL4 VMM PD | AArch64 virtualization library with virtio device support |
| musllibc | git HEAD | seL4 PDs | seL4-adapted musl C library |
| Micro-XRCE-DDS Agent | 2.4.3 | Linux VM guest | DDS agent bridging micro-ROS to the ROS 2 ecosystem |
| micro_ros_setup | ROS Humble | - | micro-ROS workspace generation tools |

## License

MIT - see [LICENSE](./LICENSE).
