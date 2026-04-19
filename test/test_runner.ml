(** Test runner for the combining tree using OCaml 5 Domains *)

open Combining_tree

(** Sequential test to verify basic functionality *)
let test_sequential () =
  Printf.printf "=== Sequential Test ===\n";
  let counter = ref 0 in
  for i = 0 to 9 do
    let result = Tree.fetch_and_increment_seq counter in
    Printf.printf "Thread %d got value: %d\n" i result
  done;
  Printf.printf "Final counter value: %d\n\n" !counter

(** Concurrent test using OCaml 5 Domains *)
let test_concurrent () =
  Printf.printf "=== Concurrent Test ===\n";
  let tree = Tree.create_tree 3 in
  let num_threads = 10 in
  let domains = ref [] in
  
  (* Spawn domains to perform concurrent fetch_and_increment *)
  for i = 0 to num_threads - 1 do
    let domain = Domain.spawn (fun () ->
      let result = Tree.fetch_and_increment tree in
      Printf.printf "Domain %d got value: %d\n" i result
    ) in
    domains := domain :: !domains
  done;
  
  (* Wait for all domains to finish *)
  List.iter Domain.join !domains;
  Printf.printf "Concurrent test completed\n\n"

(** Run all tests *)
let () =
  Printf.printf "Software Combining Tree Test Suite\n";
  Printf.printf "===================================\n\n";
  test_sequential ();
  test_concurrent ();
  Printf.printf "All tests completed!\n"
