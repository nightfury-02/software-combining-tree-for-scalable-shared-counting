open Types

(** Tree construction and fetch_and_increment logic for the combining tree *)

(** Create a leaf node with IDLE status *)
let create_leaf () : node =
  {
    status = Atomic.make IDLE;
    first_value = Atomic.make 0;
    second_value = Atomic.make 0;
    result = Atomic.make 0;
    parent = None;
    left = None;
    right = None;
  }

(** Create a root node with ROOT status *)
let create_root () : node =
  {
    status = Atomic.make ROOT;
    first_value = Atomic.make 0;
    second_value = Atomic.make 0;
    result = Atomic.make 0;
    parent = None;
    left = None;
    right = None;
  }

(** Create a tree with given height *)
let rec create_tree_internal height is_root : node =
  if height = 0 then
    create_leaf ()
  else
    let left = create_tree_internal (height - 1) false in
    let right = create_tree_internal (height - 1) false in
    let node = if is_root then create_root () else create_leaf () in
    let updated_left = { left with parent = Some node } in
    let updated_right = { right with parent = Some node } in
    { node with left = Some updated_left; right = Some updated_right }

(** Create a tree with given height and mark root as ROOT *)
let create_tree height : node =
  create_tree_internal height true

(** Fetch and increment operation on the combining tree *)
let fetch_and_increment leaf =
  (* Phase 1: Ascend (Precombine) - traverse up the tree via precombine *)
  let path = Stack.create () in
  let rec ascend_precombine curr _is_first_at_prev =
    let became_first = Node.precombine curr in
    Stack.push (curr, became_first) path;
    
    if became_first then begin
      (* Thread became FIRST at curr - continue ascending *)
      match curr.parent with
      | Some parent -> ascend_precombine parent became_first
      | None ->
          (* Reached root while being FIRST - root is already ROOT *)
          (curr, became_first)
    end else begin
      (* Thread became SECOND at curr - stop here (this is combining node) *)
      (curr, became_first)
    end
  in
  
  let (stop_node, is_first_at_stop) = ascend_precombine leaf true in

  (* Phase 2: Ascend (Combine) - pop stack from stop_node and accumulate *)
  let combined = ref 1 in
  
  (* Pop nodes from stop_node back to leaf, combining values *)
  while not (Stack.is_empty path) do
    let (curr, _was_first) = Stack.pop path in
    let is_first_here = curr == stop_node && is_first_at_stop in
    combined := Node.combine curr !combined is_first_here
  done;

  (* Phase 3: Operation - perform atomic add at stop_node *)
  let prior = Node.op stop_node !combined in

  (* Phase 4: Descend (Distribute) - rebuild path from leaf to stop_node and distribute *)
  let rec collect_path_to_stop curr collected =
    if curr == stop_node then
      curr :: collected
    else
      match curr.parent with
      | Some parent -> collect_path_to_stop parent (curr :: collected)
      | None -> 
          (* Should have found stop_node *)
          collected
  in
  
  let descent_path = collect_path_to_stop leaf [] in
  List.iter (fun node -> 
    Node.distribute node prior is_first_at_stop
  ) descent_path;

  prior


