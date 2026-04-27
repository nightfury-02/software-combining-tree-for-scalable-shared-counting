(** Types for the combining tree *)

(** Node record representing a node in the combining tree *)
type 'a node = {
  status : int Atomic.t;               (** 0=IDLE, >0=joined count, -1=LOCKED, -2=RESULT *)
  depart_count : int Atomic.t;         (** Counter for followers exiting *)
  joined_count : int Atomic.t;         (** Final count of threads joined in this round *)
  values : 'a option Atomic.t array;   (** Array of follower contributions *)
  results : 'a option Atomic.t array;  (** Results to be read by followers *)
  result : 'a Atomic.t;                (** Root level combined aggregate result *)
  mutable parent : 'a node option;
  mutable children : 'a node array;
  fanout : int;
}
