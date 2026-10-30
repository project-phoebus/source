{ CAL_$GET_INFO - return a copy of the timezone record.

  Image addresses:
    sau2  0x00E68568  CAL_$GET_INFO

  Status stored: none.
}

procedure cal_$get_info(out tz_rec: cal_$timezone_rec_t);
begin
  tz_rec := cal_$timezone;
end;
