{ TIME_$Q_SCAN_QUEUE - run a time queue's expired elements.

  Image addresses:
    sau2  0x00E16E94  TIME_$Q_SCAN_QUEUE

  - Under the queue's spin lock each expired head element is taken off;
    a repeating one is put back at its expiry plus its interval.
  - Its callback is queued on DXM's unwired or wired queue (the lock
    released meanwhile) when the element says so, else called at once.
    The timer is then set up for the new head, if any.

  Status stored: none.
}

{ TODO(pascal) TIME_$Q_SCAN_QUEUE's 8 unexplained frame bytes

  The SAU2 frame has 8 bytes no declared local or temporary accounts
  for and nothing addresses.  A `with elem^ do' temporary would take 4,
  but the image keeps elem in a register, as a plain reference does.
  Nothing is declared for them. }

[section(wired_proc, wired_data)]
procedure time_$q_scan_queue(var queue: time_$queue_t;
                             in now: time_$clock_t;
                             out status: status_$t);
var
  expire: time_$clock_t;
  elem: time_$queue_elem_ptr_t;
  token: pinteger;
  check_dup: boolean;
begin
  { the lock (shared with the loop's last statement) }
  token := ml_$spin_lock(queue.lock);

  while queue.head <> nil do begin
    elem := queue.head;
    expire := elem^.expire;
    if expire <> now then
      if sub48(expire, now) then
        exit;

    { off the queue; a repeating one back }
    queue.head := elem^.next;
    elem^.next := nil;
    elem^.flags := elem^.flags - [0];
    if 1 in elem^.flags then begin
      add48(elem^.expire, elem^.interval);
      discard(time_$q_insert_sorted(queue, elem^));
    end;

    { the callback }
    check_dup := 4 in elem^.flags;
    if (2 in elem^.flags) or else (3 in elem^.flags) then begin
      ml_$spin_unlock(queue.lock, token);
      if 2 in elem^.flags then
        dxm_$add_callback(dxm_$unwired_q, elem^.callback,
                          addr(elem^.callback_arg), 4, check_dup, status)
      else
        dxm_$add_callback(dxm_$wired_q, elem^.callback,
                          addr(elem^.callback_arg), 4, check_dup, status);
      token := ml_$spin_lock(queue.lock);
    end
    else
      time_$callback_t(elem^.callback)^(elem);
  end;

  if queue.head <> nil then
    time_$q_setup_timer(queue, now);
  ml_$spin_unlock(queue.lock, token);
end;
