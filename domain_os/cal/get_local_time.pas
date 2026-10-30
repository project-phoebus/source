{ CAL_$GET_LOCAL_TIME - the clock with the local offset and the drift.

  Image addresses:
    sau2  0x00E6859A  CAL_$GET_LOCAL_TIME

  - The offset is the timezone's UTC offset (minutes) as a 48-bit clock.

  Status stored: none.
}

procedure cal_$get_local_time(out clock: time_$clock_t);
var
  offset: time_$clock_t;
begin
  cal_$sec_to_clock(cal_$timezone.utc_delta * 60, offset);
  time_$clock(clock);
  add48(clock, offset);
  add48(clock, cal_$timezone.drift);
end;
