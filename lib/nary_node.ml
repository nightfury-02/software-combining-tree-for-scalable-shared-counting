open Nary_types

(** N-ary node operations for the combining tree *)

(** Precombine phase: lock-free via CAS with spin loop *)
let rec precombine node =
  let s = Atomic.get node.status in
  if s = 0 then begin
    (* Try to become the Combiner (index 0) *)
    if Atomic.compare_and_set node.status 0 1 then
      (true, 0)
    else
      precombine node
  end else if s > 0 && s < node.fanout then begin
    (* Try to join as Follower *)
    let s_new = s + 1 in
    if Atomic.compare_and_set node.status s s_new then
      (false, s) (* Return index = s (since it's 0-indexed, meaning if 1 joined, index is 1) *)
    else
      precombine node
  end else begin
    (* Status is either LOCKED (-1) or RESULT (-2) or completely full. Spin and retry. *)
    Domain.cpu_relax ();
    precombine node
  end

(** Combiner tries to lock the node, preventing more joins. *)
let rec lock_for_combine node =
  let s = Atomic.get node.status in
  if s > 0 then begin
    if Atomic.compare_and_set node.status s (-1) then
      s (* Returns the total number of threads that joined *)
    else
      lock_for_combine node
  end else if s = -1 then begin
    (* Should not happen normally if we are the combiner, but just in case *)
    assert false
  end else begin
    (* Wait, if s=0, how could it be 0 if we are the combiner? It can't. *)
    Domain.cpu_relax ();
    lock_for_combine node
  end

(** Wait for a specific follower to deposit its value *)
let rec wait_for_value node index =
  match Atomic.get node.values.(index) with
  | Some v -> v
  | None ->
      Domain.cpu_relax ();
      wait_for_value node index

(** Wait for the combiner to deliver results *)
let rec wait_for_result node =
  if Atomic.get node.status <> -2 then begin
    Domain.cpu_relax ();
    wait_for_result node
  end
