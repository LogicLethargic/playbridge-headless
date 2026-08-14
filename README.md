# PlayBridge Headless Receiver

A small downstream patch for the PlayBridge CLI that exposes its existing receiver runtime without starting the Ratatui dashboard.

## Why this exists

PlayBridge CLI 0.2.0 made the full-screen dashboard the primary interface, including receiver mode. The receiver implementation itself already has a non-dashboard execution path: `run_receiver_mode(..., None)` starts the receiver host, handles pairing and playback commands, launches mpv, and exits cleanly on Ctrl+C. The CLI simply does not expose that path as a command.

This project adds one explicit flag:

```text
playbridge receiver --headless
```

The normal `playbridge receiver` behavior is unchanged.

## What it changes

- Adds `--headless` to the `receiver` command.
- Routes directly to the existing receiver runtime instead of the dashboard.
- Keeps PlayBridge discovery, WSS receiver hosting, pairing, queue handling, and mpv playback in the upstream implementation.
- Keeps Ctrl+C shutdown behavior from the existing receiver runtime.
- Does **not** attempt to reverse-engineer or replace the PlayBridge protocol.

## Build

The patch is intentionally kept separate from the upstream source tree. `scripts/build.sh` clones the upstream PlayBridge repository, checks out the requested revision, applies the patch, and builds the CLI.

```bash
./scripts/build.sh
```

By default it builds against the PlayBridge `main` branch. To pin a revision:

```bash
PLAYBRIDGE_REF=be8cae4aecac8e65d3c15bdade11f9b7771df2b7 ./scripts/build.sh
```

The resulting binary is written to `dist/playbridge`.

## Run

```bash
./dist/playbridge receiver --headless
```

Optional receiver settings remain available:

```bash
./dist/playbridge receiver --headless --name "NetRunner15" --port 8765
```

The receiver prints its listening port and pairing events to stdout/stderr instead of rendering a dashboard.

## systemd

An example user service is provided in `systemd/playbridge-headless.service`. Edit the `ExecStart` path for your installation, then enable it with your normal user-systemd workflow.

## Current investigation

On Fedora 43 with PlayBridge CLI 0.2.0, the stock receiver dashboard was observed consuming roughly one CPU core. `strace` showed repeated terminal redraw activity from the receiver process, including repeated `/dev/tty` size checks and writes of terminal escape sequences. The headless route removes that dashboard loop rather than trying to hide it behind a pseudo-terminal.

## Upstream

This is a downstream patch for [PlayBridge](https://github.com/playbridgeapp/playbridge). PlayBridge's CLI is Rust-based and its current CLI manifest identifies version 0.2.0; the receiver runtime is implemented in `cli/src/receive.rs`.

PlayBridge is licensed upstream under AGPL-3.0-or-later. This repository contains only the downstream patch, build tooling, service example, and investigation notes; it does not redistribute the upstream source tree.

## Status

Experimental downstream patch. The goal is a minimal, maintainable change that can eventually be proposed upstream rather than becoming a permanently separate receiver implementation.
