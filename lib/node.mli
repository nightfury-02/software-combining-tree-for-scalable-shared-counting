(** Interface for CAS-based node operations *)

open Types

(** Perform a compare-and-swap operation on the status field *)
val cas_status : 'a node -> status -> status -> bool

(** Precombine phase: thread announces its operation at the node *)
val precombine : 'a node -> 'a -> unit

(** Combine phase: combine multiple operations into one *)
val combine : 'a node -> ('a -> 'a -> 'a) -> unit

(** Obtain the operation: returns the current operation at the node *)
val op : 'a node -> 'a option

(** Distribute phase: distribute the combined result *)
val distribute : 'a node -> unit
