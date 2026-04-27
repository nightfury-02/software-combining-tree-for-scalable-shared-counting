open Combining_tree

type counter_type =
  | AtomicFAA of Baseline.counter
  | CASLoop of Baseline.counter
  | CombiningTree of int Tree.t
  | NaryCombiningTree of int Nary_tree.t

let run_experiment ~counter ~num_threads ~increments_per_thread =
  let barrier = Atomic.make 0 in
  let start_flag = Atomic.make false in

  let runner thread_id =
    (* Wait for all threads to be ready *)
    Atomic.incr barrier;
    while not (Atomic.get start_flag) do
      Domain.cpu_relax ()
    done;

    let total_latency = ref 0.0 in
    let leaf_node =
      match counter with
      | CombiningTree tree -> Some (Array.get (Tree.leaves tree) (thread_id mod Array.length (Tree.leaves tree)))
      | _ -> None
    in
    let nary_leaf_node =
      match counter with
      | NaryCombiningTree tree -> Some (Array.get (Nary_tree.leaves tree) (thread_id mod Array.length (Nary_tree.leaves tree)))
      | _ -> None
    in

    let t_start_global = Unix.gettimeofday () in

    for _ = 1 to increments_per_thread do
      let t0 = Unix.gettimeofday () in
      let _res =
        match counter, leaf_node, nary_leaf_node with
        | AtomicFAA c, _, _ -> Baseline.fetch_and_increment_atomic c
        | CASLoop c, _, _ -> Baseline.fetch_and_increment_cas_loop c
        | CombiningTree tree, Some start_node, _ -> Tree.fetch_and_increment tree ~start:start_node
        | NaryCombiningTree tree, _, Some start_node -> Nary_tree.fetch_and_increment tree ~start:start_node
        | _ -> assert false
      in
      let t1 = Unix.gettimeofday () in
      total_latency := !total_latency +. (t1 -. t0)
    done;

    let t_end_global = Unix.gettimeofday () in
    (t_end_global -. t_start_global, !total_latency)
  in

  let domains =
    List.init num_threads (fun i -> Domain.spawn (fun () -> runner i))
  in

  (* Wait for all domains to reach the barrier *)
  while Atomic.get barrier < num_threads do
    Domain.cpu_relax ()
  done;

  (* Signal them to start concurrently *)
  Atomic.set start_flag true;

  (* Wait for them all to finish and gather times *)
  let results = List.map Domain.join domains in

  (* Throughput calculation: maximum thread duration is a good proxy, or just wall-clock from start_flag to join.
     Let's do wall-clock across the entire parallel section roughly. *)
  let max_duration = List.fold_left (fun acc (d, _) -> max acc d) 0.0 results in
  let sum_total_latency = List.fold_left (fun acc (_, l) -> acc +. l) 0.0 results in
  
  let total_increments = float_of_int (num_threads * increments_per_thread) in
  let throughput = total_increments /. max_duration in
  let avg_latency = sum_total_latency /. total_increments in

  (throughput, avg_latency)


let run_all_benchmarks () =
  let num_increments = 50_000 in
  let num_runs = 5 in
  Printf.printf "Benchmarking with %d increments per thread over %d runs.\n%!" num_increments num_runs;
  Printf.printf "=========================================================================================\n%!";
  Printf.printf "%-15s | %-10s | %-20s | %-20s\n%!" "Counter Type" "Threads" "Avg Throughput (ops/s)" "Avg Latency (ns/op)";
  Printf.printf "-----------------------------------------------------------------------------------------\n%!";

  let thread_counts = [2; 3; 4; 5; 6; 7; 8] in
  
  List.iter (fun threads ->
    let counters = [
      ("Atomic FAA", fun () -> AtomicFAA (Baseline.create ~init:0));
      ("CAS Loop", fun () -> CASLoop (Baseline.create ~init:0));
      (* Combine tree with an adequate height so there's enough leaves for up to 8 threads. 
         Height 3 means 2^3 = 8 leaves. *)
      ("CombiningTree", fun () -> CombiningTree (Tree.create_counting_tree ~height:3));
      (* Nary Combining Trees for comparison *)
      ("NaryTree(fan=2)", fun () -> NaryCombiningTree (Nary_tree.create_counting_tree ~height:3 ~fanout:2));
      ("NaryTree(fan=4)", fun () -> NaryCombiningTree (Nary_tree.create_counting_tree ~height:2 ~fanout:4));
    ] in
    
    List.iter (fun (name, counter_constructor) ->
      Printf.printf "  [Running] %-15s | %-10d %!" name threads;
      
      let counter = counter_constructor () in
      let (throughput, latency_sec) = run_experiment ~counter ~num_threads:threads ~increments_per_thread:num_increments in
      let latency_ns = latency_sec *. 1_000_000_000.0 in
      Printf.printf "=> Throughput: %-20.0f | Latency: %-20.2f\n%!" throughput latency_ns
    ) counters;
    Printf.printf "-----------------------------------------------------------------------------------------\n%!";
  ) thread_counts

let () =
  run_all_benchmarks ()
