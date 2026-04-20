(** Baseline counters for comparison with combining trees *)

type counter

(** Create a new counter initialized to [init] *)
val create : init:int -> counter

(** Read the current counter value *)
val get : counter -> int

(** Increment via [Atomic.fetch_and_add], returning prior value *)
val fetch_and_increment_atomic : counter -> int

(** Increment via CAS retry loop, returning prior value *)
val fetch_and_increment_cas_loop : counter -> int
