(** Interface for CAS-based node operations *)

(** Precombine phase: thread announces its operation at the node (lock-free via CAS)
    Returns: true if thread secured FIRST status, false if SECOND *)
val precombine : Types.node -> bool

(** Combine phase: called after precombine with the thread's value and whether it was first
    Returns: the combined value ready to be passed up the tree *)
val combine : Types.node -> int -> bool -> int

(** Op phase: perform the operation at this node (either add to result or wait for it)
    Returns: the result value *)
val op : Types.node -> int -> int

(** Distribute phase: pass the result to waiting thread or reset the node
    Requires: prior result value and whether this thread was first *)
val distribute : Types.node -> int -> bool -> unit
