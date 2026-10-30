{ CAL_$SET_DRIFT - set the calendar's drift correction.

  Image addresses:
    sau2  0x00E68580  CAL_$SET_DRIFT

  - CAL_$GET_LOCAL_TIME adds the drift to the clock.

  Status stored: none.
}

procedure cal_$set_drift(in drift: time_$clock_t);
begin
  cal_$timezone.drift := drift;
end;
