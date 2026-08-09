# Installing an instance on macOS (Apple Silicon)

A path **validated** on an M1 Mac mini (macOS 14.5, 8 GB) on 5 August 2026:
native arm64 build, 332 of the gateway's tests green inside the image, with only
the 3 breakages that also fail on x86 — **no architecture-related failure**.

The platform assumes a Linux host. On a Mac you get there through a VM, and the
choice of VM matters less than the two details that follow.

## Container runtime

**Colima** (Apache-2.0) is the recommended choice for a remotely administered
machine: it is command-line native, and the VM it creates is an ordinary Linux
in which mapped uids, `root:root 700` and `setpriv` behave as they do on a real
Linux host — which is to say the platform's defences are worth what they claim.

It installs **without administrator privileges and without Homebrew**, from the
release binaries into `~/bin`: `colima`, `limactl` (with its `share/lima`
alongside) and the standalone `docker` client. With `--vm-type vz` it uses
Virtualization.framework and needs no QEMU.

```bash
colima start --vm-type vz --cpu 6 --memory 5 --disk 60 --mount-type virtiofs
```

**OrbStack** is faster on volume I/O and more convenient from a GUI, but needs a
licence for commercial use: choosing it is perfectly legitimate — it should be a
decision rather than something inherited.

**Memory budget.** On a Mac the VM is nested: macOS, the VM and the stack share
the same RAM. Measured on 8 GB with only the VM running (5 GB assigned): macOS
was left with 0.1 GB free plus 3.5 GB inactive and reclaimable, swap at zero.
Inside the VM, 4.4 GB available — which is the instance's **total** budget, the
agents' subprocesses included. On 8 GB: a reduced topology (the `pwa` can be left
out) and `multi_spawn` off from the start.

## Two details that cost time if you find them afterwards

### 1. The datadir does not belong in a folder of the Mac

With a virtiofs mount the permissions are **asymmetric**. Measured:

```
inside the VM:  drwx------ root root   → a spawn's uid is denied by the kernel ✓
from the host:  -rw-r--r-- <user>      → `cat` reads the content              ✗
```

The instance's vault — providers, tokens, keys — would then be readable by
anyone with a shell on the Mac. Use a path **inside the VM**:

```
CLODIA_DATA=/var/clodia-data
CLODIA_GATEWAY_STATE=/var/clodia-gateway-state
```

Colima mounts only the user's home, so `/var/...` lives on the VM's disk and does
not exist from macOS at all. The consequence to accept: your backup becomes the
VM's disk rather than a browsable folder — the `restic` job runs inside the
container either way, so nothing substantial changes.

### 2. Remote login: macOS keeps a separate list

On macOS `authorized_keys` is not enough: the user must belong to the access
control group, or sshd **accepts the key and then closes the session** — a
symptom that does not look like an authorisation problem.

```bash
dseditgroup -o checkmember -m <user> com.apple.access_ssh   # check
sudo dseditgroup -o edit -a <user> -t user com.apple.access_ssh
```

## Starting automatically

A VM started by hand does not survive a reboot. Container runtimes on macOS
belong to a **user session**, so starting at boot requires auto-login — a user
LaunchAgent starts at login, not at boot. With FileVault on, that is in tension:
a headless Mac that unlocks itself is a disk that is not protected at rest, and
without auto-login an unexpected reboot stops at the pre-boot screen, which on a
machine with no keyboard means a physical visit.

There is no right answer in the abstract: it depends on where the machine lives.
Choose, and write the choice down, because it is a decision that will have to be
justified later.

**The test that settles it**, whichever runtime you choose: reboot the machine
and **do not log in**. If the stack comes back and answers, it is fit for
production; if you have to unlock the Mac, it is fit for development.
