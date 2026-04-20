open Combining_tree
open Combining_tree.Types

exception Test_failure of string

let fail msg = raise (Test_failure msg)
let check cond msg = if not cond then fail msg

let status_to_string = function
  | IDLE -> "IDLE"
  | FIRST -> "FIRST"
  | SECOND -> "SECOND"
  | RESULT -> "RESULT"
  | ROOT -> "ROOT"

let rec count_nodes = function
  | { left = None; right = None; _ } -> 1
  | { left = Some l; right = Some r; _ } -> 1 + count_nodes l + count_nodes r
  | _ -> fail "Malformed tree: one child missing"

let expected_node_count height = (1 lsl (height + 1)) - 1

let expect_invalid_arg fn test_name =
  try
    fn ();
    fail (Printf.sprintf "%s: expected Invalid_argument, but none was raised" test_name)
  with
  | Invalid_argument _ -> ()
  | exn ->
      fail
        (Printf.sprintf "%s: expected Invalid_argument, got %s" test_name
           (Printexc.to_string exn))

let unique_sorted values =
  let copy = Array.copy values in
  Array.sort Int.compare copy;
  copy

let assert_contiguous_zero_based values expected_count test_name =
  check (Array.length values = expected_count)
    (Printf.sprintf "%s: expected %d values, got %d" test_name expected_count
       (Array.length values));
  let sorted = unique_sorted values in
  for i = 0 to expected_count - 1 do
    check
      (sorted.(i) = i)
      (Printf.sprintf "%s: expected value %d at sorted[%d], got %d" test_name i
         i sorted.(i))
  done

let env_int name ~default =
  match Sys.getenv_opt name with
  | None -> default
  | Some raw -> ( try int_of_string raw with _ -> default)

let test_scale () = max 1 (env_int "CT_TEST_SCALE" ~default:1)
let scaled n = max 1 (n / test_scale ())

let test_tree_shape_and_root_status () =
  let tree = Tree.create_counting_tree ~height:3 in
  let root = Tree.root tree in
  check
    (Atomic.get root.status = ROOT)
    (Printf.sprintf "root status must be ROOT, got %s"
       (status_to_string (Atomic.get root.status)));
  Array.iter
    (fun n ->
      match (n.left, n.right) with
      | None, None -> ()
      | Some l, Some r ->
          (match l.parent with
          | Some p -> check (p == n) "left child parent link is broken"
          | None -> fail "left child parent link is missing");
          (match r.parent with
          | Some p -> check (p == n) "right child parent link is broken"
          | None -> fail "right child parent link is missing")
      | _ -> fail "Malformed internal node")
    (Tree.nodes tree)

let test_create_tree_argument_validation () =
  expect_invalid_arg
    (fun () -> ignore (Tree.create_tree ~height:(-1) ~init:0 ~combine:( + )))
    "test_create_tree_argument_validation"

let test_height_zero_tree_properties () =
  let tree = Tree.create_counting_tree ~height:0 in
  let root = Tree.root tree in
  check (Atomic.get root.status = ROOT) "height=0 root must be ROOT";
  check (root.parent = None) "height=0 root should have no parent";
  check (root.left = None && root.right = None)
    "height=0 root should have no children"

let test_tree_size_by_height () =
  for h = 0 to 6 do
    let tree = Tree.create_counting_tree ~height:h in
    let actual = count_nodes (Tree.root tree) in
    let expected = expected_node_count h in
    check
      (actual = expected)
      (Printf.sprintf "height=%d node count mismatch: expected %d got %d" h
         expected actual)
  done

let test_single_thread_basic () =
  let tree = Tree.create_counting_tree ~height:3 in
  let start = Tree.root tree in
  let calls = 64 in
  let out = Array.init calls (fun _ -> Tree.fetch_and_increment tree ~start) in
  assert_contiguous_zero_based out calls "test_single_thread_basic"

let test_single_thread_long_run () =
  let tree = Tree.create_counting_tree ~height:4 in
  let start = Tree.root tree in
  let calls = scaled 10_000 in
  let out = Array.init calls (fun _ -> Tree.fetch_and_increment tree ~start) in
  assert_contiguous_zero_based out calls "test_single_thread_long_run"

let test_fetch_from_mixed_node_positions () =
  let tree = Tree.create_counting_tree ~height:3 in
  let nodes = Tree.nodes tree in
  let calls = scaled 4_000 in
  let out =
    Array.init calls (fun i ->
        let node = nodes.(i mod Array.length nodes) in
        Tree.fetch_and_increment tree ~start:node)
  in
  assert_contiguous_zero_based out calls "test_fetch_from_mixed_node_positions"

let test_root_status_stability_under_load () =
  let tree = Tree.create_counting_tree ~height:4 in
  let root = Tree.root tree in
  let leaves = Tree.leaves tree in
  let domains = max 4 (Domain.recommended_domain_count ()) in
  let ops_per_domain = scaled 1_500 in
  let jobs =
    Array.init domains (fun d ->
        Domain.spawn (fun () ->
            for i = 0 to ops_per_domain - 1 do
              ignore
                (Tree.fetch_and_increment tree
                   ~start:leaves.((d + i) mod Array.length leaves))
            done))
  in
  Array.iter Domain.join jobs;
  check (Atomic.get root.status = ROOT)
    "root status changed under concurrent load"

let run_concurrent_count_case ~height ~domains ~ops_per_domain ~rounds ~name =
  check (height >= 0) (Printf.sprintf "%s: height must be >= 0" name);
  check (domains > 0) (Printf.sprintf "%s: domains must be > 0" name);
  check (ops_per_domain > 0)
    (Printf.sprintf "%s: ops_per_domain must be > 0" name);
  check (rounds > 0) (Printf.sprintf "%s: rounds must be > 0" name);
  for round = 1 to rounds do
    let tree = Tree.create_counting_tree ~height in
    let leaves = Tree.leaves tree in
    check
      (Array.length leaves > 0)
      (Printf.sprintf "%s: no leaves available" name);
    let total_ops = domains * ops_per_domain in
    let results = Array.make total_ops (-1) in
    let jobs =
      Array.init domains (fun d ->
          Domain.spawn (fun () ->
              for i = 0 to ops_per_domain - 1 do
                let out_idx = (d * ops_per_domain) + i in
                let leaf = leaves.((d + i) mod Array.length leaves) in
                results.(out_idx) <- Tree.fetch_and_increment tree ~start:leaf
              done))
    in
    Array.iter Domain.join jobs;
    assert_contiguous_zero_based results total_ops
      (Printf.sprintf "%s_round_%d" name round)
  done

let test_multi_thread_small () =
  run_concurrent_count_case ~height:3 ~domains:4 ~ops_per_domain:(scaled 2_000)
    ~rounds:(scaled 3)
    ~name:"test_multi_thread_small"

let test_multi_thread_medium () =
  run_concurrent_count_case ~height:4 ~domains:8 ~ops_per_domain:(scaled 3_000)
    ~rounds:(scaled 2)
    ~name:"test_multi_thread_medium"

let test_high_stress () =
  let domains = max 8 (Domain.recommended_domain_count ()) in
  run_concurrent_count_case ~height:5 ~domains ~ops_per_domain:(scaled 5_000)
    ~rounds:(scaled 2)
    ~name:"test_high_stress"

let test_concurrent_using_mixed_start_nodes () =
  let tree = Tree.create_counting_tree ~height:4 in
  let nodes = Tree.nodes tree in
  let domains = max 6 (Domain.recommended_domain_count ()) in
  let ops_per_domain = scaled 2_500 in
  let total = domains * ops_per_domain in
  let results = Array.make total (-1) in
  let jobs =
    Array.init domains (fun d ->
        Domain.spawn (fun () ->
            for i = 0 to ops_per_domain - 1 do
              let idx = (d * ops_per_domain) + i in
              let node = nodes.((d + (i * 3)) mod Array.length nodes) in
              results.(idx) <- Tree.fetch_and_increment tree ~start:node
            done))
  in
  Array.iter Domain.join jobs;
  assert_contiguous_zero_based results total "test_concurrent_using_mixed_start_nodes"

let test_max_single_thread () =
  let tree = Tree.create_tree ~height:3 ~init:min_int ~combine:Int.max in
  let start = Tree.root tree in
  let values = [| 3; 11; 5; 9; 22; 4 |] in
  Array.iteri
    (fun i v ->
      let prior = Tree.fetch_and_combine tree ~start v in
      if i = 0 then check (prior = min_int) "max prior for first op must be init")
    values;
  let final_max = Atomic.get (Tree.root tree).result in
  check (final_max = 22) "max combine should keep maximum value"

let test_max_concurrent () =
  let tree = Tree.create_tree ~height:4 ~init:min_int ~combine:Int.max in
  let starts = Tree.nodes tree in
  let domains = 8 in
  let per_domain = 400 in
  let jobs =
    Array.init domains (fun d ->
        Domain.spawn (fun () ->
            for i = 1 to per_domain do
              let value = (d * per_domain) + i in
              ignore
                (Tree.fetch_and_combine tree
                   ~start:starts.((d + i) mod Array.length starts)
                   value)
            done))
  in
  Array.iter Domain.join jobs;
  let expected_max = domains * per_domain in
  let actual_max = Atomic.get (Tree.root tree).result in
  check
    (actual_max = expected_max)
    (Printf.sprintf "concurrent max mismatch: expected %d got %d" expected_max
       actual_max)

let test_baseline_atomic_single_thread () =
  let c = Baseline.create ~init:0 in
  let calls = 1_000 in
  let out = Array.init calls (fun _ -> Baseline.fetch_and_increment_atomic c) in
  assert_contiguous_zero_based out calls "test_baseline_atomic_single_thread";
  check (Baseline.get c = calls) "atomic baseline final value mismatch"

let test_baseline_cas_single_thread () =
  let c = Baseline.create ~init:0 in
  let calls = 1_000 in
  let out = Array.init calls (fun _ -> Baseline.fetch_and_increment_cas_loop c) in
  assert_contiguous_zero_based out calls "test_baseline_cas_single_thread";
  check (Baseline.get c = calls) "cas baseline final value mismatch"

let run_baseline_concurrent_case ~name ~inc_fn =
  let c = Baseline.create ~init:0 in
  let domains = max 6 (Domain.recommended_domain_count ()) in
  let ops_per_domain = scaled 2_000 in
  let total = domains * ops_per_domain in
  let out = Array.make total (-1) in
  let jobs =
    Array.init domains (fun d ->
        Domain.spawn (fun () ->
            for i = 0 to ops_per_domain - 1 do
              out.((d * ops_per_domain) + i) <- inc_fn c
            done))
  in
  Array.iter Domain.join jobs;
  assert_contiguous_zero_based out total name;
  check (Baseline.get c = total)
    (Printf.sprintf "%s: final value mismatch" name)

let test_baseline_atomic_concurrent () =
  run_baseline_concurrent_case ~name:"test_baseline_atomic_concurrent"
    ~inc_fn:Baseline.fetch_and_increment_atomic

let test_baseline_cas_concurrent () =
  run_baseline_concurrent_case ~name:"test_baseline_cas_concurrent"
    ~inc_fn:Baseline.fetch_and_increment_cas_loop

let run_test name fn =
  try
    Printf.printf "[RUN ] %s\n%!" name;
    fn ();
    Printf.printf "[PASS] %s\n%!" name
  with
  | Test_failure msg ->
      Printf.printf "[FAIL] %s: %s\n%!" name msg;
      exit 1
  | exn ->
      Printf.printf "[FAIL] %s: unexpected exception: %s\n%!" name
        (Printexc.to_string exn);
      exit 1

let () =
  Printf.printf "Software Combining Tree Test Suite\n";
  Printf.printf "===================================\n%!";
  run_test "create_tree_argument_validation" test_create_tree_argument_validation;
  run_test "height_zero_tree_properties" test_height_zero_tree_properties;
  run_test "tree_size_by_height" test_tree_size_by_height;
  run_test "tree_shape_and_root_status" test_tree_shape_and_root_status;
  run_test "single_thread_basic" test_single_thread_basic;
  run_test "single_thread_long_run" test_single_thread_long_run;
  run_test "fetch_from_mixed_node_positions" test_fetch_from_mixed_node_positions;
  run_test "root_status_stability_under_load" test_root_status_stability_under_load;
  run_test "multi_thread_small" test_multi_thread_small;
  run_test "multi_thread_medium" test_multi_thread_medium;
  run_test "concurrent_using_mixed_start_nodes"
    test_concurrent_using_mixed_start_nodes;
  run_test "high_stress" test_high_stress;
  run_test "max_single_thread" test_max_single_thread;
  run_test "max_concurrent" test_max_concurrent;
  run_test "baseline_atomic_single_thread" test_baseline_atomic_single_thread;
  run_test "baseline_cas_single_thread" test_baseline_cas_single_thread;
  run_test "baseline_atomic_concurrent" test_baseline_atomic_concurrent;
  run_test "baseline_cas_concurrent" test_baseline_cas_concurrent;
  Printf.printf "All tests passed.\n%!"
