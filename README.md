# PlayBridge Headless Receiver

[![Status](https://img.shields.io/badge/status-experimental-orange)](https://github.com/LogicLethargic/playbridge-headless)
[![Platform](https://img.shields.io/badge/platform-Linux-informational)](https://github.com/LogicLethargic/playbridge-headless)
[![Implementation](https://img.shields.io/badge/implementation-downstream%20patch-blue)](https://github.com/LogicLethargic/playbridge-headless)

A focused downstream engineering project around **PlayBridge CLI 0.2.0**: exposing the existing receiver runtime without launching the interactive Ratatui dashboard.

This repository is intentionally **not a replacement media receiver** and does not reimplement PlayBridge's protocol. It demonstrates a smaller, more maintainable approach: inspect the existing execution path, identify the UI boundary, make the smallest possible change, and build the result reproducibly against upstream.

## The problem

The stock `playbridge receiver` command enters the full-screen dashboard. On the Fedora 43 test system used for this investigation, the receiver process could consume roughly one CPU core while otherwise idle.

A syscall trace showed the dashboard repeatedly:

- writing terminal escape sequences;
- opening `/dev/tty`;
- querying terminal dimensions with `TIOCGWINSZ`;
- closing the terminal descriptor;
- repeating the cycle at high frequency.

The important finding was that the receiver runtime itself already accepted an optional dashboard channel. The dashboard was an orchestration/UI layer rather than the receiver's fundamental runtime dependency.

## Approach

Instead of hiding the dashboard behind `nohup`, a pseudo-terminal, or a terminal emulator, the patch adds an explicit execution path:

```text
playbridge receiver --headless
             │
             ├── parse receiver arguments
             │
             ├── run_receiver_mode(arguments, None)
             │
             └── existing receiver runtime
                    ├── WSS receiver host
                    ├── pairing / control handling
                    ├── queue handling
                    └── mpv playback
```

The normal `playbridge receiver` path remains dashboard-driven.

## What changed

The downstream patch makes two deliberately small source changes:

1. Add `--headless` handling to the receiver command in `cli/src/main.rs`.
2. Expose the already-existing `run_receiver_mode` function to the command dispatcher in `cli/src/receive.rs`.

The actual receiver implementation is left upstream-owned. The patch does not copy or replace it.

## Repository layout

```text
.
├── patches/
│   └── headless-receiver.patch     # minimal upstream source patch
├── scripts/
│   ├── build.sh                    # reproducible downstream build
│   └── verify.sh                   # static patch/repository checks
├── systemd/
│   └── playbridge-headless.service # user-service example
├── CONTRIBUTING.md
├── ENGINEERING.md                  # investigation and design notes
└── README.md
```

## Build

Requirements:

- Git
- Rust/Cargo
- a working PlayBridge upstream checkout/build environment

Build from a clean upstream checkout:

```bash
./scripts/build.sh
```

Pin the upstream revision when reproducibility matters:

```bash
PLAYBRIDGE_REF=<commit-or-ref> ./scripts/build.sh
```

The binary is produced at `dist/playbridge`.

## Run

```bash
./dist/playbridge receiver --headless
```

Optional receiver settings remain available:

```bash
./dist/playbridge receiver --headless --name "NetRunner15" --port 8765
```

The headless route is intended to keep the receiver runtime attached to normal process I/O rather than rendering a full-screen terminal interface.

## Verify the patch

Run the repository checks before attempting a build:

```bash
./scripts/verify.sh
```

The verifier checks repository invariants and inspects the patch for the intended command/runtime boundary. It deliberately does not pretend to be a substitute for compiling against the selected upstream revision.

## systemd

`systemd/playbridge-headless.service` is an example **user** service. It is deliberately not hard-coded to a particular home directory or binary location; edit `ExecStart` for the local installation before enabling it.

## Engineering notes

See [`ENGINEERING.md`](ENGINEERING.md) for the investigation, observations, design constraints, failure modes, and reproducibility notes.

The project is useful as a case study in:

- profiling an unfamiliar binary from the outside;
- using `ps`, `top -H`, and `strace` to move from symptom to mechanism;
- reading a Rust CLI's command dispatch and runtime boundaries;
- making a narrow downstream patch instead of forking an entire application;
- separating UI concerns from a reusable runtime;
- pinning upstream revisions for reproducible builds;
- documenting operational deployment with systemd.

## Upstream relationship

This project targets the upstream PlayBridge project and keeps the downstream patch separate from the upstream source tree. The repository does not redistribute the upstream source tree.

PlayBridge is licensed upstream under AGPL-3.0-or-later. Consult the upstream project for its complete licensing and attribution terms.

## Status

**Experimental / portfolio engineering project.**

The goal is a clear demonstration of systems investigation and minimal-change design, with enough tooling and documentation that another engineer can understand what was changed and why.
