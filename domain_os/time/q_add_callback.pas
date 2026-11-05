{ TIME_$Q_ADD_CALLBACK - fill a queue element with a callback and queue it.

  Image addresses:
    sau2  0x00E16DD4  TIME_$Q_ADD_CALLBACK
    sau4  0x0F81778C  TIME_$Q_ADD_CALLBACK
    sau6  0x78017824  TIME_$Q_ADD_CALLBACK
    sau7  0x3C418810  TIME_$Q_ADD_CALLBACK

  - The element's expiry is when (plus now for a relative time); its
    callback, datum, flags and repeat interval are set, and
    TIME_$Q_ENTER_ELEM queues it.

  Status stored:
    status_$ok: always (TIME_$Q_ENTER_ELEM's)
}

[section(wired_proc, wired_data)]
procedure time_$q_add_callback(var queue: time_$queue_t;
                               in when: time_$clock_t;
                               is_absolute: time_$rel_abs_t;
                               in now: time_$clock_t;
                               callback: univ_ptr;
                               callback_arg: univ_ptr;
                               flags: time_$qelem_flags_t;
                               in interval: time_$clock_t;
                               var qelem: time_$queue_elem_t;
                               out status: status_$t);
begin
  qelem.expire := when;
  if is_absolute = time_$relative then
    add48(qelem.expire, now);

  qelem.callback := callback;
  qelem.callback_arg := callback_arg;
  qelem.flags := flags;
  qelem.interval := interval;

  time_$q_enter_elem(queue, now, qelem, status);
end;
