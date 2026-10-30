{ CAL_$APPLY_LOCAL_OFFSET - add the local timezone offset to a clock.

  Image addresses:
    sau2  0x00E685F8  CAL_$APPLY_LOCAL_OFFSET

  - The offset is the timezone's UTC offset (minutes) as a 48-bit clock.

  Status stored: none.
}

procedure cal_$apply_local_offset(in out clock: time_$clock_t);
var
  offset: time_$clock_t;
begin
  cal_$sec_to_clock(cal_$timezone.utc_delta * 60, offset);
  add48(clock, offset);
end;
