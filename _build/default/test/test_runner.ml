(** Test runner for the combining tree using OCaml 5 Domains *)

open Combining_tree
open Combining_tree.Types

(** Test basic tree creation *)
let test_tree_creation () =
  Printf.printf "=== Tree Creation Test ===\n";
  let tree = Tree.create_tree 2 in
  Printf.printf "Created tree of height 2\n";
  Printf.printf "Root status: %s\n" 
    (match Atomic.get tree.status with
     | IDLE -> "IDLE"
     | FIRST -> "FIRST"
     | SECOND -> "SECOND"
     | RESULT -> "RESULT"
     | ROOT -> "ROOT");
  Printf.printf "\n"

(** Test sequential behavior *)
let test_sequential () =
  Printf.printf "=== Sequential Test ===\n";
  let tree = Tree.create_tree 2 in
  let expected_results = Array.init 5 (fun i -> i) in
  let actual_results = Array.make 5 0 in
  
  for i = 0 to 4 do
    let result = Tree.fetch_and_increment tree in
    actual_results.(i) <- result;
    Printf.printf "Call %d: got %d\n" i result
  done;
  
  Printf.printf "Expected: ";
  Array.iter (Printf.printf "%d ") expected_results;
  Printf.printf "\nActual:   ";
  Array.iter (Printf.printf "%d ") actual_results;
  Printf.printf "\n";
  
  if actual_results = expected_results then
    Printf.printf "✓ Sequential test PASSED\n"
  else
    Printf.printf "✗ Sequential test FAILED\n";
  Printf.printf "\n"

(** Test simple concurrent behavior with 2 threads *)
let test_concurrent_simple () =
  Printf.printf "=== Simple Concurrent Test (2 threads) ===\n";
  let tree = Tree.create_tree 2 in
  let results = Array.make 2 (-1) in
  let lock = Mutex.create () in
  
  let domain0 = Domain.spawn (fun () ->
    Printf.printf "Thread 0 starting\n%!";
    let result = Tree.fetch_and_increment tree in
    Printf.printf "Thread 0 got %d\n%!" result;
    Mutex.lock lock;
    results.(0) <- result;
    Mutex.unlock lock
  ) in
  
  let domain1 = Domain.spawn (fun () ->
    Printf.printf "Thread 1 starting\n%!";
    let result = Tree.fetch_and_increment tree in
    Printf.printf "Thread 1 got %d\n%!" result;
    Mutex.lock lock;
    results.(1) <- result;
    Mutex.unlock lock
  ) in
  
  Printf.printf "Waiting for threads...\n%!";
  Domain.join domain0;
  Domain.join domain1;
  Printf.printf "Thread 0 result: %d\n" results.(0);
  Printf.printf "Thread 1 result: %d\n" results.(1);
  Printf.printf "\n"

(** Run all tests *)
let () =
  Printf.printf "Software Combining Tree Test Suite\n";
  Printf.printf "===================================\n\n";
  test_tree_creation ();
  test_sequential ();
  test_concurrent_simple ();
  Printf.printf "All tests completed!\n"
