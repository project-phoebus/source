{ TIME_$Q_REENTER_ELEM - requeue an element at a new expiry.

  Image addresses:
    sau2  0x00E16C8E  TIME_$Q_REENTER_ELEM

  - Under the queue's spin lock the element is taken off the queue, its
    expiry set to when (plus now for a relative time) and inserted in
    order.
  - A new head sets up the queue's timer again, unless its interrupt is
    being handled.

  Status stored:
    status_$ok: requeued (also when it was not queued or not found)
    the removal's status: any other removal failure
}

[section(wired_proc, wired_data)]
procedure time_$q_reenter_elem(var queue: time_$queue_t;
                               in when: time_$clock_t;
                               is_absolute: time_$rel_abs_t;
                               in now: time_$clock_t;
                               var elem: time_$queue_elem_t;
                               out status: status_$t);
var
  rm_status: status_$t;
  token: pinteger;
begin
  { off the queue }
  token := ml_$spin_lock(queue.lock);
  time_$q_remove_internal(queue, elem, rm_status);
  if (rm_status.all <> status_$ok) and then
     (rm_status.all <> time_$q_elem_not_found) and then
     (rm_status.all <> time_$q_elem_not_in_use) then begin
    ml_$spin_unlock(queue.lock, token);
    status := rm_status;
    return;
  end;

  { the new expiry, back in order }
  elem.expire := when;
  if is_absolute = time_$relative then
    add48(elem.expire, now);
  if time_$q_insert_sorted(queue, elem) then
    if queue.virtual then begin
      if not in_vt_int then
        time_$q_setup_timer(queue, now);
    end
    else if not in_rt_int then
      time_$q_setup_timer(queue, now);

  ml_$spin_unlock(queue.lock, token);
  status.all := status_$ok;
end;
