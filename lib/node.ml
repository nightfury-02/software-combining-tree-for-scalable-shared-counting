open Types

let rec precombine node =
  let s = Atomic.get node.status in
  match s with
  | IDLE ->
      if Atomic.compare_and_set node.status IDLE FIRST then (true, 0)
      else precombine node
  | FIRST when node.fanout > 1 ->
      if Atomic.compare_and_set node.status FIRST SECOND then (false, 1)
      else precombine node
  | SECOND when node.fanout > 2 ->
      if Atomic.compare_and_set node.status SECOND THIRD then (false, 2)
      else precombine node
  | THIRD when node.fanout > 3 ->
      if Atomic.compare_and_set node.status THIRD FOURTH then (false, 3)
      else precombine node
  | _ ->
      Domain.cpu_relax ();
      precombine node

let rec lock_for_combine node =
  let s = Atomic.get node.status in
  match s with
  | FIRST | SECOND | THIRD | FOURTH ->
      if Atomic.compare_and_set node.status s LOCKED then
        match s with
        | FIRST -> 1
        | SECOND -> 2
        | THIRD -> 3
        | FOURTH -> 4
        | _ -> assert false
      else lock_for_combine node
  | _ ->
      Domain.cpu_relax ();
      lock_for_combine node

let rec wait_for_value node index =
  match Atomic.get node.values.(index) with
  | Some v -> v
  | None ->
      Domain.cpu_relax ();
      wait_for_value node index

let rec wait_for_result node =
  if Atomic.get node.status <> RESULT then begin
    Domain.cpu_relax ();
    wait_for_result node
  end
