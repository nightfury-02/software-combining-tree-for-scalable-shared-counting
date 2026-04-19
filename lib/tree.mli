(** Interface for tree construction and fetch_and_increment operations *)

open Types

(** Create a leaf node *)
val create_leaf : unit -> 'a node

(** Create a tree with given height *)
val create_tree : int -> int node

(** Fetch and increment operation on the combining tree *)
val fetch_and_increment : int node -> int

(** Sequential fetch_and_increment for testing and comparison *)
val fetch_and_increment_seq : int ref -> int
