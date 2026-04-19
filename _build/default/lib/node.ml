open Types

(** CAS-based node operations for the combining tree *)

(** Precombine phase: lock-free via CAS with spin loop *)
let rec precombine node =
  let s = Atomic.get node.status in
  match s with
  | IDLE ->
      if Atomic.compare_and_set node.status IDLE FIRST then
        true
      else
        precombine node  (* Retry if CAS failed *)
  | FIRST ->
      if Atomic.compare_and_set node.status FIRST SECOND then
        false
      else
        precombine node  (* Retry if CAS failed *)
  | ROOT ->
      (* At the root - it stays ROOT, but we treat the first arrival as FIRST *)
      true
  | SECOND | RESULT ->
      Domain.cpu_relax ();
      precombine node  (* Spin wait and retry *)

(** Combine phase: lock-free via CAS - called after precombine *)
let combine node combined_val is_first =
  if is_first then begin
    (* Thread was first: store first_value and return it *)
    Atomic.set node.first_value combined_val;
    combined_val
  end else begin
    (* Thread was second: store second_value and compute sum *)
    Atomic.set node.second_value combined_val;
    let first = Atomic.get node.first_value in
    first + combined_val
  end

(** Op phase: perform the operation at this node *)
let op node combined_val =
  let s = Atomic.get node.status in
  match s with
  | ROOT | FIRST ->
      (* Atomically add to result using CAS loop *)
      let rec fetch_add () =
        let old = Atomic.get node.result in
        if Atomic.compare_and_set node.result old (old + combined_val) then
          old
        else begin
          Domain.cpu_relax ();
          fetch_add ()
        end
      in
      fetch_add ()
  | SECOND ->
      (* Spin-wait for result to be available *)
      let rec wait_for_result () =
        if Atomic.get node.status <> RESULT then begin
          Domain.cpu_relax ();
          wait_for_result ()
        end
      in
      wait_for_result ();
      let res = Atomic.get node.result in
      (* Only reset to IDLE if not the root *)
      if node.parent <> None then
        Atomic.set node.status IDLE;
      res
  | _ ->
      (* Should not reach here *)
      combined_val

(** Distribute phase: pass result to waiting thread or reset *)
let distribute node prior is_first =
  let is_root = node.parent = None in
  if is_first then begin
    (* First thread resets the node, unless it's the root *)
    if not is_root then
      Atomic.set node.status IDLE
    (* Root stays ROOT permanently *)
  end else begin
    (* Second thread calculates result and signals *)
    let new_res = prior + Atomic.get node.first_value in
    Atomic.set node.result new_res;
    if not is_root then
      Atomic.set node.status RESULT
    else
      Atomic.set node.status ROOT
  end
