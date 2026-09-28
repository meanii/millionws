# Local benchmark

The local benchmark answers one question for each version of the server: how many idle WebSocket connections fit in a container with 1 CPU and 1 GiB of memory, and what does each one cost. It runs on one machine with Docker Compose and needs no cloud account.

## Setup

```mermaid
flowchart LR
  L1[loadgen 1] --> S
  L2[loadgen 2] --> S
  L3[loadgen ...] --> S
  L5[loadgen 5] --> S
  S["server<br/>1 CPU, 1 GiB, no swap"]
  P[Prometheus] -. scrapes .-> S
  P -. scrapes .-> L1
  R[record.py] -. cgroup files and /metrics .-> S
```

- The server container is limited with `cpus: 1`, `mem_limit: 1g`, and `memswap_limit: 1g`, so it cannot swap. Its file descriptor limit is 1,048,576, and `somaxconn` is raised to 65,535 inside its network namespace.
- Five load generator containers (`cmd/loadgen`) share the target between them. Each has its own IP address and a local port range of 1024 to 65535, so each can open about 64,000 connections to `server:8080`; five of them can open about 320,000.
- The load generators are not limited, so they are not the bottleneck. They run on the same host, so they compete with the server for host CPU.
- Every connection sends a 32-byte text message every 30 seconds and waits for the echo. The connections are mostly idle, which is the case this project studies.

## What is measured

`bench/local/record.py` takes a sample every 2 seconds from two places:

| Source | Values |
| --- | --- |
| The server container's cgroup (`memory.current`, `memory.stat`, `cpu.stat`) | Total memory charged to the container, split into anonymous memory (the Go process), kernel slab memory, and socket buffers; CPU time |
| The server's `/metrics` endpoint, read directly | Active connections, goroutines, open file descriptors, Go heap, process RSS |
| Prometheus | Load generator totals: connections, dial errors, echo latency percentiles |

The cgroup number is the one that decides when the kernel OOM-kills the container. It includes kernel memory for each socket, which the process RSS does not show: at 190,000 connections the kernel held about 715 MiB and the Go process about 210 MiB.

Memory per connection is `(value at peak - value when idle) / connections at peak`.

The server's metrics are read directly rather than from Prometheus because Prometheus keeps returning the last scraped value for a few seconds after the server dies. The first version of the recorder paired those stale connection counts with an empty cgroup and reported the wrong peak.

## When a run stops

A run stops at the first of:

- the server container exits (for example OOM-killed, exit code 137);
- the connection count has not grown by more than 0.5% for 90 seconds;
- the target is reached and held for 60 seconds;
- 30 minutes have passed.

The load generators keep dialing until the target is reached, so the dial errors at the end show what refused the connections: `handshake` for the server's 503 answer, `refused` or `reset` after the server died, `timeout` for dropped SYNs.

## Variants

Each file in `bench/local/variants/` names a git commit of the server. `run.sh` builds that commit with its own Dockerfile (`git archive <ref> | docker build -`), so older versions are measured with the current harness and the same limits.

| Variant | Commit | Server change |
| --- | --- | --- |
| `gorilla` | `99609ad` | gorilla/websocket, one goroutine per connection, logs every message |
| `nbio-initial` | `27b4027` | nbio event loop, as first written |
| `nbio-fixes` | `1b82b39` | no panic on failed upgrade, no log line per disconnect |
| `nbio-ipv4` | `4e46794` | IPv4 listener instead of dual-stack `[::]` |
| `nbio-memlimit` | `9a1d737` | Go memory limit follows the cgroup limit minus kernel memory |
| `nbio-guard` | `dadb29f` | 503 for new connections above 90% of the memory limit |
| `nbio-tuned` | `476f773` | Go memory limit set 2 points under the guard |

## Running it

Requirements: Docker with Compose, Python 3, and about 3 GiB of free memory (1 GiB for the server, the rest for the load generators).

```sh
bench/local/run.sh nbio-tuned              # one run, 300,000 target, 5 load generators
bench/local/run.sh gorilla 50000 1         # smaller target, 1 load generator
bench/local/matrix.sh 3                    # every variant 3 times, then a comparison table
KEEP=1 bench/local/run.sh nbio-fixes       # leave the stack running, e.g. to take a heap profile
```

Each run writes `results/local/<date>-<variant>/`:

| File | Contents |
| --- | --- |
| `environment.md` | Host, kernel, Docker, limits, load settings, server commit |
| `idle.json` | Sample before any client connects |
| `samples.csv` | Every sample during the run |
| `summary.md`, `summary.json` | Peak, memory per connection, stop reason, dial errors |
| `server.log`, `loadgen.log` | Last lines of each log |

`KEEP=1` also serves Prometheus on `127.0.0.1:19090`. Add `--profile grafana` to a `docker compose up` in `bench/local` to get Grafana on `127.0.0.1:18001`.

## Limits of this setup

- The load generators and the server share one host. Echo latency includes time spent waiting for host CPU, so it is only comparable between runs on the same machine.
- On this machine Docker runs rootless. Container-to-container traffic goes through the conntrack table of Docker's network namespace, which allows 262,144 entries. No run came close to it, but a server with more memory would reach it before 300,000 connections.
- One CPU core is shared by the Go runtime, the GC, and nbio's event loops. When the memory limit binds, the GC uses a large share of it, which shows up as higher CPU and echo latency.
