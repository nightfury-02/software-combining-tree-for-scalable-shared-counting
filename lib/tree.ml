open Types

(** Tree construction and fetch_and_increment logic for the combining tree *)

(** Create a node with optional ROOT status *)
let create_node is_root : node =
  {
    status = Atomic.make (if is_root then ROOT else IDLE);
    first_value = Atomic.make 0;
    second_value = Atomic.make 0;
    result = Atomic.make 0;
    parent = None;
    left = None;
    right = None;
  }

(** Create a leaf node with IDLE status *)
let create_leaf () : node = create_node false

(** Create a root node with ROOT status *)
let create_root () : node = create_node true

(** Create a tree with given height *)
let rec create_tree_internal height parent is_root : node =
  let node = create_node is_root in
  node.parent <- parent;
  if height > 0 then begin
    let left = create_tree_internal (height - 1) (Some node) false in
    let right = create_tree_internal (height - 1) (Some node) false in
    node.left <- Some left;
    node.right <- Some right
  end;
  node

(** Create a tree with given height and mark root as ROOT *)
let create_tree height : node =
  if height < 0 then
    invalid_arg "Tree.create_tree: height must be >= 0";
  create_tree_internal height None true

(** Fetch and increment operation.
    Start from any node in the tree and perform an atomic increment at root. *)
let fetch_and_increment node =
  let rec find_root curr =
    match curr.parent with
    | Some parent -> find_root parent
    | None -> curr
  in
  let root = find_root node in
  Node.op root 1
