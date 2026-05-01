# Software Combining Tree for Scalable Shared Counting

Shared counters are a deceptively simple concurrent object: every thread wants to `fetchAndIncrement`. Under high contention, even a single Atomic counter becomes a bottleneck as every CAS triggers a cache-line invalidation broadcast across your multiple cores. 

As presented in *The Art of Multiprocessor Programming* (AoMPP Chapter 12), the **software combining tree** is an elegant alternative to this problem: threads are arranged at the leaves of a binary tree and combine their increments as they move up. At each internal node, the first thread to arrive waits; the second thread to arrive combines both increments into one, carries the combined value up the tree, and on the way back down distributes the results. Only one CAS reaches the root per pair of concurrent increments, dynamically reducing contention from `O(n)` to `O(log n)`. 

This OCaml 5 implementation generalizes the combining tree beyond counting, supporting arbitrary associative combining functions (`'a -> 'a -> 'a`) like max-finding, and features dynamically configurable internal *Fan-out* structures to study architectural scaling.

---

## Features Implemented

- **OCaml 5 Native Parallelism**: Built on modern Domains for true multi-core mapping.
- **Strict AoMPP Node States**: Tracks transitions cleanly `(IDLE, FIRST, SECOND, RESULT, ROOT)`.
- **Generalized Operations**: Supports completely associative combine algorithms.
- **Tunable Topology**: Constructs complete binary `fan-out 2` or wider `fan-out 4` hierarchies.
- **Validation Matrices**: Hardened against race conditions natively through QCheck-Lin.

---

## Build and Execute

Ensure OCaml 5.0+ and Dune 3.0+ are installed. OCaml 5 automatically schedules Domains across your physical machine cores gracefully, so you don't need arbitrary core-assignment flags!

### Compilation
```bash
dune build
```

### Running the Test Suite (Including Max-Finding)
To spin up the native test suite covering structure boundaries, single-thread validation, and maximum-stress concurrency:
```bash
dune exec test/test_runner.exe
```

### Running QCheck-Lin & TSAN Validation
To formally verify linearizability against random permutations:
```bash
dune runtest
```

### Benchmarking Profiles
To trace the operational limits of generic arrays against Atomic FAA and CAS Loops:
```bash
dune exec bench/bench_main.exe
```
*(Note: Using `dune exec` routes your output through Dune's compiler buffers. The output matrix will appear on screen all at once when the script finishes its execution averages!)*

---

## Project Layout

```
software-combining-tree/
├── bench/
│   └── bench_main.ml     # Execution driver for cross-architecture topology speedouts
├── lib/
│   ├── types.ml          # Strict assignment enum states and node tracking
│   ├── node.ml           # State machine transitions (precombine, lock)
│   ├── tree.ml           # Tree ascending grouping and payload descent distribution
│   └── baseline.ml       # Standard loop and fetching counters
└── test/
    ├── test_runner.ml    # Sequential and concurrent load matrices (plus max-testing)
    └── qcheck_lin_combining_tree.ml # Linearizability execution module
```

## Presentation Video

- `https://youtu.be/Sqh8m_soEH0`
