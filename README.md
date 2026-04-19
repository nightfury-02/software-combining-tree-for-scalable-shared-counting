# Software Combining Tree for Scalable Shared Counting

A lock-free, concurrent implementation of a Software Combining Tree in OCaml 5. This project implements the combining tree algorithm described in *The Art of Multiprocessor Programming* using Compare-and-Swap (CAS) atomic operations and OCaml 5 Domains for concurrent execution.

## Overview

The combining tree is a scalable, wait-free data structure for performing shared counting operations in highly concurrent environments. Instead of having all threads contend on a single lock or atomic counter, threads coordinate at multiple levels of a tree structure, which reduces contention and improves scalability.

**Key Features:**
- Lock-free synchronization using CAS-based atomic operations
- OCaml 5 Domains for true concurrency
- Proper thread combining at internal tree nodes
- Scalable shared counter implementation
- Sequential and concurrent testing

## Prerequisites

You need to have the following installed:

- **OCaml 5.0+** (with Domains support)
- **Dune 3.0+** (OCaml build system)
- **Opam** (OCaml package manager) - optional, but recommended

### Installation

On Ubuntu/Debian:
```bash
sudo apt-get install ocaml opam build-essential
opam switch create 5.0.0
eval $(opam env)
```

On macOS:
```bash
brew install ocaml opam
opam switch create 5.0.0
eval $(opam env)
```

## Building the Project

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/combining-tree.git
   cd combining-tree
   ```

2. **Build the project:**
   ```bash
   dune build
   ```

   This will compile the library and test executable.

## Running Tests

Run the complete test suite:
```bash
dune exec test/test_runner.exe
```

### Test Descriptions

1. **Tree Creation Test**: Verifies that the tree is properly initialized with the root marked as `ROOT` status
2. **Sequential Test**: Runs 5 sequential `fetch_and_increment` operations to verify basic correctness
3. **Concurrent Test**: Spawns 2 concurrent OCaml Domains performing `fetch_and_increment` simultaneously

Expected output:
```
Software Combining Tree Test Suite
===================================

=== Tree Creation Test ===
Created tree of height 2
Root status: ROOT

=== Sequential Test ===
Call 0: got 0
Call 1: got 1
Call 2: got 2
Call 3: got 3
Call 4: got 4
Expected: 0 1 2 3 4 
Actual:   0 1 2 3 4 
✓ Sequential test PASSED

=== Simple Concurrent Test (2 threads) ===
Thread 0 starting
Thread 0 got 0
Waiting for threads...
Thread 1 starting
Thread 1 got 1
Thread 0 result: 0
Thread 1 result: 1

All tests completed!
```

## Project Structure

```
combining-tree/
├── dune-project              # Project configuration
├── README.md                 # This file
├── lib/
│   ├── dune                  # Library build file
│   ├── types.ml              # Type definitions (status enum, node record)
│   ├── types.mli             # Types interface
│   ├── node.ml               # CAS-based node operations
│   ├── node.mli              # Node interface
│   ├── tree.ml               # Tree construction and fetch_and_increment logic
│   ├── tree.mli              # Tree interface
│   └── combining_tree.mli    # Main library interface
└── test/
    ├── dune                  # Test executable build file
    └── test_runner.ml        # Test suite with OCaml 5 Domains
```

## Algorithm Overview

### Four Phases of Operation

Each call to `fetch_and_increment` follows the combining tree algorithm:

1. **Ascend (Precombine)**: Threads traverse upward from a leaf node using CAS-based synchronization
   - First thread to arrive at a node: transitions IDLE → FIRST
   - Second thread to arrive at a node: transitions FIRST → SECOND and stops
   
2. **Combine**: The second thread waits while the first thread continues ascending
   - Values are accumulated at each node

3. **Operation**: At the combining node, the accumulated value is atomically added to the result

4. **Descend (Distribute)**: Results are distributed back down the tree to waiting threads

### Status State Machine

Each node maintains a status field with four possible states:

- **IDLE**: Node is inactive
- **FIRST**: First thread has arrived
- **SECOND**: Second thread has arrived; combining in progress
- **RESULT**: Result is ready for distribution
- **ROOT**: Reserved for the root node (never changes)

## Implementation Details

### CAS-based Synchronization

The implementation uses OCaml 5's `Atomic` module for lock-free coordination:

```ocaml
Atomic.compare_and_set node.status IDLE FIRST  (* Try to acquire as FIRST *)
Atomic.get node.status                         (* Read current status *)
```

### Thread Coordination Example

When two threads reach the same leaf node:

```
Thread 0                          Thread 1
├─ Read: status = IDLE
├─ CAS: IDLE → FIRST ✓           (reads IDLE, fails CAS)
│                                ├─ Read: status = FIRST
│                                ├─ CAS: FIRST → SECOND ✓
│ (continues ascending)          └─ Waits for result
├─ Ascends tree...
├─ Reaches combining node
├─ Performs op()
├─ Distributes result ───────────> Wakes up with result
└─ Returns prior value           └─ Returns result
```

## References

This implementation is based on the combining tree algorithm from:

- **The Art of Multiprocessor Programming** (3rd Edition)
  - Chapter 11: Combining Tree for Counting
  - Authors: Maurice Herlihy, Nir Shavit, Victor Luchangco, Michael Spear

## Performance Considerations

- Optimal tree height: Log₂(number of threads)
- For N threads, use a tree of height ≈ log₂(N)
- Each thread starts at a different leaf to minimize contention
- The combining tree reduces coordination overhead from O(N) to O(log N)

## Contributing

Contributions are welcome! Please ensure:
- Code follows OCaml style guidelines
- All tests pass with `dune test`
- New features include test coverage

## License

MIT

## Questions & Support

For issues or questions about the implementation, please file an issue on GitHub.
