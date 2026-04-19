(** Types for the combining tree *)

(** Status of a node in the combining tree *)
type status =
  | Idle       (** Node is idle and waiting *)
  | First      (** First thread at this node *)
  | Second     (** Second thread at this node *)
  | Locked     (** Node is locked during combining *)

(** Node record representing a node in the combining tree *)
type 'a node = {
  mutable op : 'a option;           (** Operation to be performed *)
  mutable result : 'a option;       (** Result of the combined operation *)
  mutable status : status;          (** Current status of the node *)
  mutable delta : 'a option;        (** Accumulated delta value *)
  left : 'a node option;            (** Left child *)
  right : 'a node option;           (** Right child *)
  parent : 'a node option;          (** Parent node *)
}
