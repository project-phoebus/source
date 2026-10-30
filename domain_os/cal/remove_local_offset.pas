{ CAL_$REMOVE_LOCAL_OFFSET - subtract the local timezone offset from a
  clock.

  Image addresses:
    sau2  0x00E68634  CAL_$REMOVE_LOCAL_OFFSET

  - CAL_$APPLY_LOCAL_OFFSET's mirror; SUB48's result is dropped.

  Status stored: none.
}

procedure cal_$remove_local_offset(in out clock: time_$clock_t);
var
  offset: time_$clock_t;
begin
  cal_$sec_to_clock(cal_$timezone.utc_delta * 60, offset);
  discard(sub48(clock, offset));
end;
