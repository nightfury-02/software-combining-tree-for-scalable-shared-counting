type counter = { value : int Atomic.t }

let create ~init = { value = Atomic.make init }
let get t = Atomic.get t.value

let fetch_and_increment_atomic t = Atomic.fetch_and_add t.value 1

let fetch_and_increment_cas_loop t =
  let rec loop () =
    let old = Atomic.get t.value in
    if Atomic.compare_and_set t.value old (old + 1) then
      old
    else begin
      Domain.cpu_relax ();
      loop ()
    end
  in
  loop ()
