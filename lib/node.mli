open Types

val precombine : 'a node -> bool * int
val lock_for_combine : 'a node -> int
val wait_for_value : 'a node -> int -> 'a
val wait_for_result : 'a node -> unit
