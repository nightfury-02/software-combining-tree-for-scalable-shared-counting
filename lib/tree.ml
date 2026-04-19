open Types

(** Tree construction and fetch_and_increment logic for the combining tree *)

(** Create a leaf node *)
let create_leaf () : 'a node =
  {
    op = None;
    result = None;
    status = Idle;
    delta = None;
    left = None;
    right = None;
    parent = None;
  }

(** Create a tree with given height *)
let rec create_tree height : int node =
  if height = 0 then
    create_leaf ()
  else
    let left = create_tree (height - 1) in
    let right = create_tree (height - 1) in
    let node = create_leaf () in
    let updated_left = { left with parent = Some node } in
    let updated_right = { right with parent = Some node } in
    { node with left = Some updated_left; right = Some updated_right }

(** Fetch and increment operation on the combining tree *)
let rec fetch_and_increment node =
  (* Announce operation at this node *)
  Node.precombine node 1;
  
  (* Wait at this node and perform combining *)
  let result = ref None in
  
  (* Check if we can combine with other operations *)
  match node.status with
  | Idle ->
      node.status <- First;
      (* Wait for another thread or proceed to parent *)
      (match node.parent with
       | Some parent -> 
           let parent_result = fetch_and_increment parent in
           result := node.result;
           parent_result
       | None ->
           (* This is the root, finalize *)
           node.status <- Idle;
           Option.value !result ~default:0)
  | First ->
      (* Another thread has arrived, combine *)
      node.status <- Locked;
      Node.combine node (fun a b -> a + b);
      Node.distribute node;
      node.status <- Idle;
      Option.value node.result ~default:0
  | _ ->
      Option.value !result ~default:0

(** Alternative sequential implementation for testing *)
let fetch_and_increment_seq counter =
  let old_value = !counter in
  counter := !counter + 1;
  old_value
