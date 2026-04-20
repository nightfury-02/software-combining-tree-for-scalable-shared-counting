open Types

(** Tree construction and generic combine logic for the combining tree *)

type 'a t = {
  root : 'a node;
  leaves : 'a node array;
  nodes : 'a node array;
  combine : 'a -> 'a -> 'a;
}

(** Create a node with optional ROOT status *)
let create_node is_root init : 'a node =
  {
    status = Atomic.make (if is_root then ROOT else IDLE);
    first_value = Atomic.make None;
    second_value = Atomic.make None;
    result = Atomic.make init;
    parent = None;
    left = None;
    right = None;
  }

(** Create a tree with given height *)
let rec create_tree_internal height parent is_root init : 'a node =
  let node = create_node is_root init in
  node.parent <- parent;
  if height > 0 then begin
    let left = create_tree_internal (height - 1) (Some node) false init in
    let right = create_tree_internal (height - 1) (Some node) false init in
    node.left <- Some left;
    node.right <- Some right
  end;
  node

let rec collect_leaves node =
  match (node.left, node.right) with
  | None, None -> [ node ]
  | Some l, Some r -> collect_leaves l @ collect_leaves r
  | _ -> invalid_arg "Tree.collect_leaves: malformed tree"

let rec collect_nodes node =
  match (node.left, node.right) with
  | None, None -> [ node ]
  | Some l, Some r -> node :: (collect_nodes l @ collect_nodes r)
  | _ -> invalid_arg "Tree.collect_nodes: malformed tree"

let create_tree ~height ~init ~combine : 'a t =
  if height < 0 then
    invalid_arg "Tree.create_tree: height must be >= 0";
  let root = create_tree_internal height None true init in
  {
    root;
    leaves = Array.of_list (collect_leaves root);
    nodes = Array.of_list (collect_nodes root);
    combine;
  }

let root t = t.root
let leaves t = t.leaves
let nodes t = t.nodes

let fetch_and_combine t ~start value =
  let rec find_root curr =
    match curr.parent with
    | Some parent -> find_root parent
    | None -> curr
  in
  let root_node = find_root start in
  Node.op t.combine root_node value

let create_counting_tree ~height = create_tree ~height ~init:0 ~combine:( + )
let fetch_and_increment t ~start = fetch_and_combine t ~start 1
