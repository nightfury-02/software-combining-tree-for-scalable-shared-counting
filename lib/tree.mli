(** Interface for tree construction and generic combine operations *)

type 'a t

(** Create a tree with given height, fanout, initial accumulator, and associative combine op *)
val create_tree : height:int -> fanout:int -> init:'a -> combine:('a -> 'a -> 'a) -> 'a t

(** Root node of the tree *)
val root : 'a t -> 'a Types.node

(** Leaf nodes of the tree *)
val leaves : 'a t -> 'a Types.node array

(** All nodes in the tree *)
val nodes : 'a t -> 'a Types.node array

(** Atomically combine a value into the tree accumulator from a chosen start node.
    Returns the prior aggregate value. *)
val fetch_and_combine : 'a t -> start:'a Types.node -> 'a -> 'a

(** Convenience API for counting (addition with +1 updates). *)
val create_counting_tree : height:int -> fanout:int -> int t
val fetch_and_increment : int t -> start:int Types.node -> int
