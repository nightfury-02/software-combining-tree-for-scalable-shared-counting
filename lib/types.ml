(** Types for the combining tree *)

type status =
  | IDLE
  | FIRST
  | SECOND
  | THIRD
  | FOURTH
  | RESULT
  | ROOT
  | LOCKED

type 'a node = {
  status : status Atomic.t;               
  depart_count : int Atomic.t;         
  joined_count : int Atomic.t;         
  values : 'a option Atomic.t array;   
  results : 'a option Atomic.t array;  
  result : 'a Atomic.t;                
  mutable parent : 'a node option;
  mutable children : 'a node array;
  fanout : int;
}
