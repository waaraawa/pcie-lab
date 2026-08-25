# Tests

- `guest/` contains host-independent tests that run inside the Linux guest.
- `expected/` defines expected functional results and comparison rules shared by all hosts.

Host provisioning and QEMU lifecycle checks belong under `scripts/macos/` or `scripts/wsl/`, not in the guest functional tests.
