# Software Combining Tree for Scalable Shared Counting

A lock-free, concurrent implementation of a **Software Combining Tree** in **OCaml 5**, designed to reduce contention in shared counters using hierarchical aggregation, atomic synchronization, and tunable fan-out structures.

---

## Overview

In concurrent systems, shared counters become performance bottlenecks due to contention among threads. This project implements a **combining tree**, where threads dynamically group and aggregate operations across a generalized tree structure before applying them to the shared root value. 

### Why Combine?
By utilizing a Fan-out 4 vs Fan-out 2 structure, internal tree coordination delays are slashed, providing massive latency reductions under contention while effortlessly bypassing Intel's physical hardware interconnect limitations once threads exceed the optimal single-cache-line limit!

The implementation uses:
- **OCaml 5 Domains** for multi-core true parallel execution
- **CAS (Compare-And-Swap)** for lock-free synchronization without deadlocks
- A **Dynamic Fan-out Parameter** allowing deep analysis into combining node widths
- A **generic associative function** (`'a -> 'a -> 'a`) for flexible aggregation

---

## Setup & Build Instructions

Ensure the following are installed:
- OCaml **5.0+**
- Dune **3.0+**

```bash
git clone https://github.com/nightfury-02/software-combining-tree-for-scalable-shared-counting.git
cd software-combining-tree-for-scalable-shared-counting
dune build
```

---

## Benchmarking Performance

To rigorously execute the configured benchmarking framework, run the executable directly (to avoid Dune wrapper stdout buffering under heavy scaling conditions):

```bash
dune build bench/bench_main.exe && ./_build/default/bench/bench_main.exe
```

### OCaml 5 Core Utilization Note
OCaml 5 domains naturally map onto physical hardware CPU cores globally out-of-the-box. You **do not** need to export deprecated flags like `OCAMLRUNPARAM="D=4"` (which were native to old pre-release Multicore variants). OCaml handles thread balancing gracefully across the operating system.

### Expected Output
The framework averages metrics over 5 concurrent scaling cycles, comparing Hardware FAA against the Native generic Combining Tree at Fan-outs of 2 and 4. You will see scaling profiles that mirror memory contention breaking thresholds.

---

## Project Structure

```
software-combining-tree/
├── bench/
│   ├── bench_main.ml     # Iterative driver comparing cross-fanout tree performance
│   └── dune
├── lib/
│   ├── types.ml          # Atomic core structural definitions 
│   ├── node.ml           # State machine logic (PRECOMBINE, LOCK, RESULT)
│   ├── tree.ml           # Tree ASCEND and DESCEND aggregation loop algorithms
│   ├── tree.mli
│   ├── node.mli
│   ├── baseline.ml
│   └── dune
└── test/
    ├── test_runner.ml
    ├── qcheck_lin_combining_tree.ml
    └── dune
```

---

## Algorithm Details

Each operation dynamically progresses across dynamic leaf branches:

1. **Precombine (Ascend)**
   - A thread arrives at a combining node and attempts to join via CAS loops.
   - The *first* thread instantly locks the node as the `Combiner`.
   - Threads arriving immediately after become `Followers`.
2. **Combine**
   - The Combiner waits to collect inputs from all registered followers.
   - The group value is aggregated into a single payload, traversing upwards.
3. **Distribution**
   - After the root applies the unified total, the Combiner descends.
   - Results are precisely distributed to each distinct follower's memory array slot.
   - The node safely unlocks, opening itself for the next round of combinations.

## License
MIT
