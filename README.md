# Software Combining Tree for Scalable Shared Counting

A lock-free, concurrent implementation of a **Software Combining Tree** in **OCaml 5**, designed to reduce contention in shared counters using hierarchical aggregation and atomic synchronization.

---

## Overview

In concurrent systems, shared counters become performance bottlenecks due to contention among threads. This project implements a **combining tree**, where threads aggregate operations across a tree structure before applying them to a shared value. This reduces contention and improves scalability.

The implementation uses:
- **OCaml 5 Domains** for parallel execution  
- **CAS (Compare-And-Swap)** for lock-free synchronization  
- A **generic associative function** (`'a -> 'a -> 'a`) for flexible aggregation  

---

## Features

- Lock-free synchronization using atomic operations  
- Scalable tree-based contention reduction  
- Generic operation support (sum, max, etc.)  
- Parallel execution using OCaml Domains  
- Comprehensive correctness testing  
- Benchmarking support for performance evaluation  

---

## Prerequisites

Ensure the following are installed:

- OCaml **5.0+**
- Dune **3.0+**
- Opam (recommended)

### Setup (Linux)

```bash
sudo apt-get install ocaml opam build-essential
opam switch create 5.0.0
eval $(opam env)
```

### Setup (macOS)

```bash
brew install ocaml opam
opam switch create 5.0.0
eval $(opam env)
```

---

## Build Instructions

```bash
git clone https://github.com/yourusername/combining-tree.git
cd combining-tree
dune build
```

---

## Running Tests

```bash
dune runtest
```

Or run directly:

```bash
dune exec test/test_runner.exe
```

### Expected Output

```
Software Combining Tree Test Suite
===================================

[PASS] tree_shape_and_root_status
[PASS] single_thread_basic
[PASS] single_thread_long_run
[PASS] multi_thread_small
[PASS] multi_thread_medium
[PASS] high_stress

All tests passed.
```

---

## Benchmarking

### Run Benchmark

```bash
dune exec bench/ben
```

### Control Parallelism

```bash
OCAMLRUNPARAM="D=4" dune exec test/bench.exe
```

---

### Metrics Measured

- Execution time  
- Throughput (operations/sec)  
- Scalability vs number of domains  

---

### Example Output

```
Domains: 4
Operations per domain: 100000

Atomic FAA:        0.12s
CAS Loop:          0.45s
Combining Tree:    0.20s
```

---

### Interpretation

- **Atomic FAA** → Best for low contention  
- **CAS Loop** → Poor performance under contention  
- **Combining Tree** → Scales better with higher contention  

---

## Project Structure

```
combining-tree/
├── dune-project
├── README.md
├── lib/
│   ├── types.ml
│   ├── node.ml
│   ├── tree.ml
│   ├── tree.mli
│   └── combining_tree.mli
└── test/
    ├── test_runner.ml
    └── bench.ml
```

---

## Algorithm Summary

Each operation follows four phases:

1. **Precombine (Ascend)**
   - Threads move up the tree
   - First thread marks node as FIRST
   - Second thread marks node as SECOND  

2. **Combine**
   - Values are aggregated at nodes  

3. **Operation**
   - Root applies combined result  

4. **Distribute (Descend)**
   - Results propagated back to threads  

---

## Implementation Details

- Uses `Atomic.compare_and_set` for synchronization  
- Avoids locks → no blocking or deadlocks  
- Tree height ≈ `log₂(number_of_threads)`  
- One leaf per thread to reduce contention  

---

## Performance Considerations

- Best performance achieved under high contention  
- Overhead exists for small workloads  
- Tree structure reduces contention from **O(N) → O(log N)**  

---

## Common Issues

### Program not using multiple cores
```bash
OCAMLRUNPARAM="D=4" dune exec ...
```

### Slow benchmark
- Reduce operations per thread  
- Adjust domain count  

### Incorrect results
- Check CAS usage  
- Ensure atomic updates are correct  

---

## References

- *The Art of Multiprocessor Programming* — Herlihy & Shavit  
- OCaml 5 Domains Documentation  

---

## License

MIT

---

## Author

Project developed as part of a Concurrent Programming course.
