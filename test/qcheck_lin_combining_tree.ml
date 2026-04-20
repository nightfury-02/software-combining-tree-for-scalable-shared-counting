(** QCheck-Lin Linearizability Test for Combining Tree *)

module CT = Combining_tree.Tree

module CTSig = struct
  type t = int CT.t

  let init () = CT.create_counting_tree ~height:3

  let cleanup _ = ()

  open Lin

  let fetch_and_inc t =
    let leaves = CT.leaves t in
    (* Domain ids are sequential integers starting from 0 (or some base) *)
    (* In OCaml 5, we can use Domain.self() cast to int to spread contention evenly *)
    let idx = (Domain.self () :> int) in
    let start = leaves.(idx mod Array.length leaves) in
    CT.fetch_and_increment t ~start

  (** API: non-blocking fetch_and_increment *)
  let api =
    [ val_ "fetch_and_increment" fetch_and_inc (t @-> returning int); ]
end

module CT_domain = Lin_domain.Make(CTSig)

let () =
  QCheck_base_runner.run_tests_main [
    CT_domain.lin_test ~count:50 ~name:"CombiningTree linearizability";
  ]
