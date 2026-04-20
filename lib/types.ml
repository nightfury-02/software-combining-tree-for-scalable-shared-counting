(** Types for the combining tree *)

(** Status of a node in the combining tree *)
type status =
  | IDLE       (** Node is idle and waiting *)
  | FIRST      (** First thread at this node *)
  | SECOND     (** Second thread at this node *)
  | RESULT     (** Result is available *)
  | ROOT       (** This is the root node *)

(** Node record representing a node in the combining tree *)
type 'a node = {
  status : status Atomic.t;         (** Current status of the node (CAS-based) *)
  first_value : 'a option Atomic.t; (** Value from first thread *)
  second_value : 'a option Atomic.t;(** Value from second thread *)
  result : 'a Atomic.t;             (** Result of the combined operation *)
  mutable parent : 'a node option;  (** Parent node *)
  mutable left : 'a node option;    (** Left child *)
  mutable right : 'a node option;   (** Right child *)
}
