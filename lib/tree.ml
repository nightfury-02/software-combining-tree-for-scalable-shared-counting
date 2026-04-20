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
  let rec ascend node current_val stack =
    let is_first = Node.precombine node in
    if is_first then begin
      if node.parent = None then begin
        let stack = (node, true, false, current_val) :: stack in
        (stack, current_val)
      end else begin
        if Atomic.compare_and_set node.status FIRST IDLE then begin
          let stack = (node, true, false, current_val) :: stack in
          ascend (Option.get node.parent) current_val stack
        end else begin
          let rec wait_for_sec () =
            match Atomic.get node.second_value with
            | Some v -> v
            | None -> Domain.cpu_relax (); wait_for_sec ()
          in
          let sec = wait_for_sec () in
          let combined = t.combine current_val sec in
          let stack = (node, true, true, current_val) :: stack in
          ascend (Option.get node.parent) combined stack
        end
      end
    end else begin
      Atomic.set node.second_value (Some current_val);
      let stack = (node, false, false, current_val) :: stack in
      (stack, current_val)
    end
  in
  let (stack, final_val) = ascend start value [] in

  let (top_node, _, _, _) = List.hd stack in
  let root_prior = Node.op t.combine top_node final_val in

  let rec descend prior stack =
    match stack with
    | [] -> prior
    | (node, is_first, has_second, my_val) :: rest ->
        if is_first then begin
          if has_second then begin
            let t2_res = t.combine prior my_val in
            Atomic.set node.result t2_res;
            Atomic.set node.second_value None;
            Atomic.set node.status RESULT;
            descend prior rest
          end else begin
            descend prior rest
          end
        end else begin
          descend prior rest
        end
  in
  descend root_prior stack

let create_counting_tree ~height = create_tree ~height ~init:0 ~combine:( + )
let fetch_and_increment t ~start = fetch_and_combine t ~start 1
