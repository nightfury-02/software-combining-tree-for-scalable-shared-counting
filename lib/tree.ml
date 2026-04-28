open Types

type 'a t = {
  root : 'a node;
  leaves : 'a node array;
  nodes : 'a node array;
  combine : 'a -> 'a -> 'a;
  fanout : int;
}

let create_node fanout init is_root : 'a node =
  {
    status = Atomic.make (if is_root then ROOT else IDLE);
    depart_count = Atomic.make 0;
    joined_count = Atomic.make 0;
    values = Array.init fanout (fun _ -> Atomic.make None);
    results = Array.init fanout (fun _ -> Atomic.make None);
    result = Atomic.make init;
    parent = None;
    children = [||];
    fanout;
  }

let rec create_tree_internal height fanout parent init is_root : 'a node =
  let node = create_node fanout init is_root in
  node.parent <- parent;
  if height > 0 then begin
    let children = Array.init fanout (fun _ -> create_tree_internal (height - 1) fanout (Some node) init false) in
    node.children <- children
  end;
  node

let rec collect_leaves node =
  if Array.length node.children = 0 then [node]
  else Array.fold_left (fun acc c -> acc @ collect_leaves c) [] node.children

let rec collect_nodes node =
  if Array.length node.children = 0 then [node]
  else node :: Array.fold_left (fun acc c -> acc @ collect_nodes c) [] node.children

let create_tree ~height ~fanout ~init ~combine : 'a t =
  if height < 0 then invalid_arg "Tree: height must be >= 0";
  if fanout < 1 then invalid_arg "Tree: fanout must be >= 1";
  let root = create_tree_internal height fanout None init true in
  {
    root;
    leaves = Array.of_list (collect_leaves root);
    nodes = Array.of_list (collect_nodes root);
    combine;
    fanout;
  }

let leaves t = t.leaves
let root t = t.root
let nodes t = t.nodes

let fetch_and_combine t ~start value =
  let rec ascend node current_val stack =
    if Atomic.get node.status = ROOT then begin
      let rec atomic_combine () =
        let old = Atomic.get node.result in
        let next = t.combine old current_val in
        if Atomic.compare_and_set node.result old next then old
        else begin Domain.cpu_relax (); atomic_combine () end
      in
      let prior = atomic_combine () in
      (stack, prior)
    end else begin
      let (is_combiner, index) = Node.precombine node in
      if is_combiner then begin
        let count = Node.lock_for_combine node in
        let follower_values = Array.make (count - 1) current_val in
        for i = 1 to count - 1 do
          follower_values.(i - 1) <- Node.wait_for_value node i
        done;
        let total_val = ref current_val in
        for i = 0 to count - 2 do
          total_val := t.combine !total_val follower_values.(i)
        done;
        let stack = (node, count, current_val, follower_values) :: stack in
        ascend (Option.get node.parent) !total_val stack
      end else begin
        Atomic.set node.values.(index) (Some current_val);
        Node.wait_for_result node;
        let prior =
          match Atomic.get node.results.(index) with
          | Some v -> v
          | None -> assert false
        in
        let total_followers = (Atomic.get node.joined_count) - 1 in
        let left = Atomic.fetch_and_add node.depart_count 1 in
        if left + 1 = total_followers then begin
          Atomic.set node.depart_count 0;
          Atomic.set node.status IDLE;
        end;
        (stack, prior)
      end
    end
  in
  let (stack, prior_from_top) = ascend start value [] in

  let rec descend prior stack =
    match stack with
    | [] -> prior
    | (node, count, my_val, follower_values) :: rest ->
        Atomic.set node.joined_count count;
        Atomic.set node.results.(0) (Some prior);
        let current_prior = ref (t.combine prior my_val) in
        for i = 1 to count - 1 do
          Atomic.set node.results.(i) (Some !current_prior);
          current_prior := t.combine !current_prior follower_values.(i - 1)
        done;
        for i = 1 to count - 1 do
          Atomic.set node.values.(i) None
        done;
        if count = 1 then begin
          Atomic.set node.status IDLE
        end else begin
          Atomic.set node.status RESULT
        end;
        descend prior rest
  in
  descend prior_from_top stack

let create_counting_tree ~height ~fanout = create_tree ~height ~fanout ~init:0 ~combine:( + )
let fetch_and_increment t ~start = fetch_and_combine t ~start 1
