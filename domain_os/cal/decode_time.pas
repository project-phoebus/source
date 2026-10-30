{ CAL_$DECODE_TIME - a 48-bit clock to year, month, day, hour, minute and
  second.

  Image addresses:
    sau2  0x00E6873A  CAL_$DECODE_TIME

  - Years count from 1980, a leap year, every fourth year one; the
    seconds, minutes and hours come off by unsigned `mod' and `div'.

  Status stored: none.
}

procedure cal_$decode_time(in clock: time_$clock_t;
                           out clockh_rec: cal_$timedate_rec_t);
var
  local_days: array[1..12] of integer;
  secs: linteger;
  days_in_year: integer;
  cumulative: integer;
  month_no: integer;
  i: integer;
begin
  with clockh_rec do begin
    for i := 1 to 12 do
      local_days[i] := cal_$days_per_month[i];

    secs := cal_$clock_to_sec(clock);
    second := secs mod 60;
    secs := secs div 60;
    minute := secs mod 60;
    secs := secs div 60;
    hour := secs mod 24;
    secs := secs div 24;

    { the years from 1980 }
    days_in_year := 366;
    secs := secs + 1;
    local_days[2] := 29;
    year := 1980;
    while days_in_year < secs do begin
      secs := secs - days_in_year;
      year := year + 1;
      if year mod 4 = 0 then begin
        days_in_year := 366;
        local_days[2] := 29;
      end
      else begin
        days_in_year := 365;
        local_days[2] := 28;
      end;
    end;

    { the months }
    cumulative := 0;
    for month_no := 1 to 12 do begin
      if cumulative + local_days[month_no] >= secs then
        exit;
      cumulative := cumulative + local_days[month_no];
    end;

    month := month_no;
    day := secs - cumulative;
  end;
end;
