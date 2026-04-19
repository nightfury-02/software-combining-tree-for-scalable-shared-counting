(** Interface for tree construction and fetch_and_increment operations *)

(** Create a leaf node *)
val create_leaf : unit -> Types.node

(** Create a root node with ROOT status *)
val create_root : unit -> Types.node

(** Fetch and increment operation on the combining tree
    Starting from a leaf node, traverses up the tree via CAS-based precombine,
    performs combining at the appropriate node, and returns the prior value *)
val fetch_and_increment : Types.node -> int

(** Create a tree with given height *)
val create_tree : int -> Types.node
