{ TIME_$ADVANCE - arrange for an eventcount to be advanced at a time.

  Image addresses:
    sau2  0x00E16454  TIME_$ADVANCE

  - The element is queued on the real-time queue at when (relative or
    absolute), with TIME_$ADVANCE_CALLBACK and the eventcount as its
    datum; it does not repeat.

  Status stored:
    status_$ok: always (TIME_$Q_ENTER_ELEM's)
}

procedure time_$advance(in is_absolute: time_$rel_abs_t;
                        in when: time_$clock_t;
                        var ec: ec_$eventcount_t;
                        var elem: time_$queue_elem_t;
                        out status: status_$t);
var
  now: time_$clock_t;
begin
  time_$abs_clock(now);
  time_$q_add_callback(time_$rteq, when, is_absolute, now,
                       addr(time_$advance_callback), addr(ec), [],
                       zero_interval, elem, status);
end;
