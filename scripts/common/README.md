# Common Scripts

This directory is reserved for host-independent validation logic shared by macOS and WSL. Move logic here only after both host workflows use it and its inputs are explicit.

Do not hide host-specific QEMU acceleration, filesystem, networking, or provisioning behavior behind condition-heavy common scripts.
