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

let rec collect_leaves node =
  match (node.left, node.right) with
  | None, None -> [ node ]
  | Some l, Some r -> collect_leaves l @ collect_leaves r
  | _ -> fail "Malformed tree: one child missing"

let rec collect_nodes node =
  match (node.left, node.right) with
  | None, None -> [ node ]
  | Some l, Some r -> node :: (collect_nodes l @ collect_nodes r)
  | _ -> fail "Malformed tree: one child missing"

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
  | Some raw -> (
      try int_of_string raw with _ -> default)

let test_scale () = max 1 (env_int "CT_TEST_SCALE" ~default:1)

let scaled n = max 1 (n / test_scale ())

let test_tree_shape_and_root_status () =
  let tree = Tree.create_tree 3 in
  check
    (Atomic.get tree.status = ROOT)
    (Printf.sprintf "root status must be ROOT, got %s"
       (status_to_string (Atomic.get tree.status)));
  let nodes = collect_nodes tree in
  List.iter
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
    nodes

let test_create_tree_argument_validation () =
  expect_invalid_arg
    (fun () -> ignore (Tree.create_tree (-1)))
    "test_create_tree_argument_validation"

let test_height_zero_tree_properties () =
  let tree = Tree.create_tree 0 in
  check (Atomic.get tree.status = ROOT) "height=0 root must be ROOT";
  check (tree.parent = None) "height=0 root should have no parent";
  check (tree.left = None && tree.right = None)
    "height=0 root should have no children"

let test_tree_size_by_height () =
  for h = 0 to 6 do
    let tree = Tree.create_tree h in
    let actual = count_nodes tree in
    let expected = expected_node_count h in
    check
      (actual = expected)
      (Printf.sprintf "height=%d node count mismatch: expected %d got %d" h
         expected actual)
  done

let test_single_thread_basic () =
  let tree = Tree.create_tree 3 in
  let calls = 64 in
  let out = Array.init calls (fun _ -> Tree.fetch_and_increment tree) in
  assert_contiguous_zero_based out calls "test_single_thread_basic"

let test_single_thread_long_run () =
  let tree = Tree.create_tree 4 in
  let calls = scaled 10_000 in
  let out = Array.init calls (fun _ -> Tree.fetch_and_increment tree) in
  assert_contiguous_zero_based out calls "test_single_thread_long_run"

let test_fetch_from_mixed_node_positions () =
  let tree = Tree.create_tree 3 in
  let nodes = Array.of_list (collect_nodes tree) in
  let calls = scaled 4_000 in
  let out =
    Array.init calls (fun i ->
        let node = nodes.(i mod Array.length nodes) in
        Tree.fetch_and_increment node)
  in
  assert_contiguous_zero_based out calls "test_fetch_from_mixed_node_positions"

let test_root_status_stability_under_load () =
  let tree = Tree.create_tree 4 in
  let leaves = Array.of_list (collect_leaves tree) in
  let domains = max 4 (Domain.recommended_domain_count ()) in
  let ops_per_domain = scaled 1_500 in
  let jobs =
    Array.init domains (fun d ->
        Domain.spawn (fun () ->
            for i = 0 to ops_per_domain - 1 do
              ignore (Tree.fetch_and_increment leaves.((d + i) mod Array.length leaves))
            done))
  in
  Array.iter Domain.join jobs;
  check (Atomic.get tree.status = ROOT)
    "root status changed under concurrent load"

let run_concurrent_case ~height ~domains ~ops_per_domain ~rounds ~name =
  check (height >= 0) (Printf.sprintf "%s: height must be >= 0" name);
  check (domains > 0) (Printf.sprintf "%s: domains must be > 0" name);
  check (ops_per_domain > 0)
    (Printf.sprintf "%s: ops_per_domain must be > 0" name);
  check (rounds > 0) (Printf.sprintf "%s: rounds must be > 0" name);
  for round = 1 to rounds do
    let tree = Tree.create_tree height in
    let leaves = Array.of_list (collect_leaves tree) in
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
                results.(out_idx) <- Tree.fetch_and_increment leaf
              done))
    in
    Array.iter Domain.join jobs;
    assert_contiguous_zero_based results total_ops
      (Printf.sprintf "%s_round_%d" name round)
  done

let test_multi_thread_small () =
  run_concurrent_case ~height:3 ~domains:4 ~ops_per_domain:(scaled 2_000)
    ~rounds:(scaled 3)
    ~name:"test_multi_thread_small"

let test_multi_thread_medium () =
  run_concurrent_case ~height:4 ~domains:8 ~ops_per_domain:(scaled 3_000)
    ~rounds:(scaled 2)
    ~name:"test_multi_thread_medium"

let test_high_stress () =
  let domains = max 8 (Domain.recommended_domain_count ()) in
  run_concurrent_case ~height:5 ~domains ~ops_per_domain:(scaled 5_000)
    ~rounds:(scaled 2)
    ~name:"test_high_stress"

let test_concurrent_using_mixed_start_nodes () =
  let tree = Tree.create_tree 4 in
  let nodes = Array.of_list (collect_nodes tree) in
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
              results.(idx) <- Tree.fetch_and_increment node
            done))
  in
  Array.iter Domain.join jobs;
  assert_contiguous_zero_based results total "test_concurrent_using_mixed_start_nodes"

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
  Printf.printf "All tests passed.\n%!"
