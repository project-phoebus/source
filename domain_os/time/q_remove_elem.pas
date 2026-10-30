{ TIME_$Q_REMOVE_ELEM - take an element off a time queue.

  Image addresses:
    sau2  0x00E16E48  TIME_$Q_REMOVE_ELEM

  - time_$q_remove_internal under the queue's spin lock.

  Status stored:
    time_$q_remove_internal's status: in either case
}

[section(wired_proc, wired_data)]
procedure time_$q_remove_elem(var queue: time_$queue_t;
                              var elem: time_$queue_elem_t;
                              out status: status_$t);
var
  local_status: status_$t;
  token: pinteger;
begin
  token := ml_$spin_lock(queue.lock);
  time_$q_remove_internal(queue, elem, local_status);
  ml_$spin_unlock(queue.lock, token);
  status := local_status;
end;
