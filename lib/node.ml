open Types

(** CAS-based node operations for the combining tree *)

(** Perform a compare-and-swap operation on the status field *)
let cas_status node expected new_status =
  if Atomic.compare_and_set (Atomic.make node.status) expected new_status then
    (node.status <- new_status; true)
  else
    false

(** Precombine phase: thread announces its operation at the node *)
let precombine node op =
  node.op <- Some op;
  node.status <- Idle

(** Combine phase: combine multiple operations into one *)
let combine node f =
  match node.op, node.delta with
  | Some op, Some delta -> 
      let combined = f op delta in
      node.delta <- Some combined
  | Some op, None -> 
      node.delta <- Some op
  | None, Some delta -> ()
  | None, None -> ()

(** Obtain the operation: returns the current operation at the node *)
let op node =
  node.op

(** Distribute phase: distribute the combined result *)
let distribute node =
  node.result <- node.delta;
  node.op <- None;
  node.status <- Idle
