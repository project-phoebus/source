{ smd_$reschedule_blink_timer - queue the cursor blink callback.

  Image addresses:
    sau2  0x00E72690  smd_$reschedule_blink_timer (module-local)
    sau4  0x0F87FC34  smd_$reschedule_blink_timer (module-local)
    sau5  0x00E79830  smd_$reschedule_blink_timer (module-local)
    sau9  0x3C47A094  smd_$reschedule_blink_timer (module-local)

  - SMD_$BLINK_CURSOR_CALLBACK goes on the real-time queue interval ticks
    from now, in the routine's static queue element; the status is not
    tested.
  - The element must be wired (the callbacks run at interrupt level):
    `[section(procedure$, wired_data)]' puts it in WIRED_DATA.
  - A 4-byte 0 is passed as TIME_$Q_ADD_CALLBACK's 6-byte interval.

  Status stored: none.
}

[section(procedure$, wired_data)]
procedure smd_$reschedule_blink_timer(interval: integer32); internal;
var
  blink_qelem: static time_$queue_elem_t; { WIRED_DATA +0x0: 0x1A bytes
                                            of zero, then the block's 2
                                            bytes of rounding }
  when: time_$clock_t;
  status: status_$t;
  now: time_$clock_t;
begin
  when.high16 := 0;
  when.low32 := interval;
  time_$abs_clock(now);
  time_$q_add_callback(time_$rteq, when, time_$relative, now,
                       addr(smd_$blink_cursor_callback), nil, [2],
                       0, blink_qelem, status);
end;
