open Combining_tree

type counter_type =
  | AtomicFAA of Baseline.counter
  | CASLoop of Baseline.counter
  | CombiningTree of int Tree.t

let run_experiment ~counter ~num_threads ~increments_per_thread =
  let barrier = Atomic.make 0 in
  let start_flag = Atomic.make false in

  let runner thread_id =
    (* Wait for all threads to be ready *)
    Atomic.incr barrier;
    while not (Atomic.get start_flag) do
      Domain.cpu_relax ()
    done;

    let leaf_node =
      match counter with
      | CombiningTree tree -> Some (Array.get (Tree.leaves tree) (thread_id mod Array.length (Tree.leaves tree)))
      | _ -> None
    in

    for _ = 1 to increments_per_thread do
      ignore
        (match counter, leaf_node with
         | AtomicFAA c, _ -> Baseline.fetch_and_increment_atomic c
         | CASLoop c, _ -> Baseline.fetch_and_increment_cas_loop c
         | CombiningTree tree, Some start_node -> Tree.fetch_and_increment tree ~start:start_node
         | _ -> assert false)
    done
  in

  let domains =
    List.init num_threads (fun i -> Domain.spawn (fun () -> runner i))
  in

  (* Wait for all domains to reach the barrier *)
  while Atomic.get barrier < num_threads do
    Domain.cpu_relax ()
  done;

  (* Start timing, then release all domains concurrently. *)
  let t_start = Unix.gettimeofday () in
  Atomic.set start_flag true;

  (* Wait for them all to finish and gather times *)
  List.iter Domain.join domains;
  let t_end = Unix.gettimeofday () in
  let duration = max 1e-12 (t_end -. t_start) in
  
  let total_increments = float_of_int (num_threads * increments_per_thread) in
  let throughput = total_increments /. duration in
  let avg_latency = duration /. total_increments in

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
      ("CombiningTree(fan=2)", fun () -> CombiningTree (Tree.create_counting_tree ~height:3 ~fanout:2));
      ("CombiningTree(fan=4)", fun () -> CombiningTree (Tree.create_counting_tree ~height:2 ~fanout:4));
    ] in
    
    List.iter (fun (name, counter_constructor) ->
      Printf.printf "  [Running] %-15s | %-10d %!" name threads;
      
      let sum_throughput = ref 0.0 in
      let sum_latency_sec = ref 0.0 in
      for _run = 1 to num_runs do
        let counter = counter_constructor () in
        let (throughput, latency_sec) =
          run_experiment ~counter ~num_threads:threads ~increments_per_thread:num_increments
        in
        sum_throughput := !sum_throughput +. throughput;
        sum_latency_sec := !sum_latency_sec +. latency_sec
      done;
      let avg_throughput = !sum_throughput /. float_of_int num_runs in
      let avg_latency_ns = (!sum_latency_sec /. float_of_int num_runs) *. 1_000_000_000.0 in
      Printf.printf "=> Throughput: %-20.0f | Latency: %-20.2f\n%!" avg_throughput avg_latency_ns
    ) counters;
    Printf.printf "-----------------------------------------------------------------------------------------\n%!";
  ) thread_counts

let () =
  run_all_benchmarks ()
