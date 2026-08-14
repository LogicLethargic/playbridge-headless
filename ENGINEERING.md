# Engineering Notes

## Objective

Investigate why PlayBridge receiver mode is expensive on a Linux desktop and determine whether the receiver runtime can be separated from the interactive dashboard with a minimal downstream change.

## 1. Establish the symptom

The receiver process was sampled with:

```bash
ps -o pid,%cpu,%mem,etime,cmd -C playbridge
```

The receiver process was observed around 73–91% CPU during the investigation.

Thread-level inspection:

```bash
top -H -p $(pgrep -x playbridge)
```

showed the main `playbridge` thread doing essentially all of the work, while the Tokio runtime worker threads were mostly sleeping.

That distinction mattered: the high CPU usage was not obviously a generic async-worker storm.

## 2. Move from CPU numbers to system-call behavior

`strace` was installed and attached to all threads:

```bash
strace -p $(pgrep -x playbridge) -c -f
```

The aggregate trace showed `epoll_wait` dominating elapsed syscall time, followed by `futex`, with very high call counts for `openat`, `write`, `close`, and `ioctl`.

That result alone was not enough to claim a cause. The next step was to inspect the actual arguments.

A focused trace was then run:

```bash
strace -f -p $(pgrep -x playbridge) \
  -e trace=openat,write,ioctl,close \
  -tt 2>&1 | head -50
```

The trace repeatedly showed this pattern from the main thread:

```text
write(1, "...terminal escape sequences...", 25)
openat(AT_FDCWD, "/dev/tty", O_RDONLY|O_CLOEXEC)
ioctl(9, TIOCGWINSZ, ...)
close(9)
```

The important observation is the repeated terminal interaction itself. This provided a concrete mechanism to investigate rather than merely correlating CPU usage with the presence of the receiver.

## 3. Inspect the executable rather than guessing at flags

The installed binary was checked with:

```bash
which playbridge
rpm -qf "$(which playbridge)"
~/.local/bin/playbridge --version
```

The binary was a user-installed executable at `~/.local/bin/playbridge`, not an RPM-managed package, and reported version `0.2.0`.

Strings inspection was useful for quickly establishing the command surface:

```bash
strings ~/.local/bin/playbridge | grep -Ei 'headless|no-ui|no_ui|interactive|terminal|tui|dashboard'
```

This revealed several relevant facts, including:

- `--no-tui` had been removed;
- interactive workflows were explicitly dashboard-based;
- `discover --json` and `discover --json-lines` were machine-oriented commands;
- the receiver command remained a dashboard command;
- the binary contained the message `Update checks are disabled by PLAYBRIDGE_NO_UPDATE_CHECK`.

The executable itself therefore did not expose the desired receiver mode through a documented headless switch.

## 4. Source inspection

The upstream CLI source was inspected rather than attempting to infer the implementation solely from binary strings.

The current CLI separates commands into dashboard and machine-oriented routes. Receiver is explicitly documented under dashboard commands, while JSON discovery and Google Cast status/launch have machine-oriented routes.

The receiver implementation contains an existing runtime function that accepts an optional dashboard command/event channel. The dashboard wrapper invokes that runtime with dashboard channels; the runtime can also be invoked without them.

That creates a clean boundary:

```text
CLI command dispatch
        │
        ├── dashboard receiver path
        │       └── receiver runtime + dashboard channels
        │
        └── proposed headless path
                └── receiver runtime + no dashboard
```

## 5. Design decision

The project deliberately avoids these approaches:

### Do not fake a terminal

Running the existing dashboard under `nohup`, `screen`, `tmux`, or a pseudo-terminal would leave the dashboard code alive. It would treat the symptom rather than remove the UI workload.

### Do not reimplement the receiver

The upstream receiver already implements the protocol, pairing, playback control, queue behavior, and mpv integration. Rewriting that stack would create unnecessary compatibility and maintenance risk.

### Do not fork the whole project

The downstream repository stores a small patch and build tooling rather than copying the PlayBridge source tree. This keeps the delta reviewable and makes upstream synchronization straightforward.

## 6. Patch strategy

The patch has two conceptual changes:

1. Detect `--headless` in the receiver command and remove that flag from the arguments passed to the receiver runtime.
2. Make the existing receiver runtime function callable from the CLI command dispatcher.

Everything else remains in upstream PlayBridge.

This is intentionally a narrow patch because the engineering goal is to demonstrate understanding of an existing codebase and its runtime boundaries, not to maximize the amount of code changed.

## 7. Reproducibility

The build script:

1. clones the upstream repository;
2. optionally checks out a requested revision;
3. applies the downstream patch;
4. builds the CLI in release mode;
5. copies the resulting executable into `dist/`.

Pinning an upstream revision is preferred for reproducible results:

```bash
PLAYBRIDGE_REF=<known-good-revision> ./scripts/build.sh
```

## 8. What has and has not been proven

### Observed

- PlayBridge 0.2.0 was the installed CLI during the investigation.
- The receiver process reached approximately one CPU core of utilization.
- The main thread accounted for essentially all of the observed process CPU.
- `strace` showed repeated `/dev/tty` opens, terminal-size ioctls, closes, and terminal writes.
- The stock command surface did not provide a documented headless receiver flag.

### Source-supported design conclusion

The receiver runtime has an optional dashboard interface, making a direct invocation without dashboard channels a substantially cleaner route than running the TUI invisibly.

### Not claimed here

This repository does not claim a specific final CPU percentage for the patched binary until it has been built and measured on the target system. The performance hypothesis should be validated empirically after compilation.

## 9. Portfolio value

The interesting part of this project is not the size of the patch. It is the chain of reasoning:

```text
symptom
  → process/thread profiling
  → syscall tracing
  → binary inspection
  → source inspection
  → identify abstraction boundary
  → minimal patch
  → reproducible build
  → measurable validation
```

That is the behavior this repository is intended to demonstrate.