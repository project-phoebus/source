{ TIME_$Q_ENTER_ELEM - put an element on a time queue.

  Image addresses:
    sau2  0x00E16D64  TIME_$Q_ENTER_ELEM

  - Under the queue's spin lock the element is inserted in expiry
    order; a new head sets up the queue's timer again, unless that
    timer's interrupt is being handled.

  Status stored:
    status_$ok: always
}

[section(wired_proc, wired_data)]
procedure time_$q_enter_elem(var queue: time_$queue_t;
                             in now: time_$clock_t;
                             var elem: time_$queue_elem_t;
                             out status: status_$t);
var
  token: pinteger;
begin
  status.all := status_$ok;
  token := ml_$spin_lock(queue.lock);

  if time_$q_insert_sorted(queue, elem) then
    if queue.virtual then begin
      if not in_vt_int then
        time_$q_setup_timer(queue, now);
    end
    else if not in_rt_int then
      time_$q_setup_timer(queue, now);

  ml_$spin_unlock(queue.lock, token);
end;
