{ CAL_$VERIFY - check the calendar against the label's last valid time.

  Image addresses:
    sau2  0x00E68380  CAL_$VERIFY

  - A failure to read the timezone record crashes the system; the drift
    correction is cleared.
  - A clock more than a minute (229 high words) behind the last valid
    time, or more than max_delta ahead, prints a message, and
    interactive asks the operator whether to go on.
  - The result is true when the calendar is accepted.

  Status stored:
    status_$ok: the calendar is accepted, or not asked about
    cal_$refused: the operator refused it
}

function cal_$verify(in max_delta: integer32; in msg_arg: univ cal_$string_t;
                     in interactive: boolean; out status_ret: status_$t):
                     boolean;
var
  tz: cal_$timezone_rec_t;
  input: array[1..8] of char;
  delta: integer32;
  st: status_$t;
begin
  cal_$verify := true;
  status_ret.all := status_$ok;

  cal_$read_timezone(tz, st);
  cal_$timezone.drift.high := 0;
  cal_$timezone.drift.low := 0;
  if st.all <> status_$ok then
    crash_system(st);

  delta := time_$clockh - cal_$last_valid_time;
  if delta < -229 then
    vfmt_$write2('%/The calendar is more than a minute slow. %.', 0, 0)
  else begin
    if delta <= max_delta then
      return;
    vfmt_$write2('%/More than %a days have elapsed since the last shutdown. %.',
                 msg_arg, 3);
  end;

  { ask the operator }
  if interactive then begin
    repeat
      vfmt_$write2('Do you want to run DOMAIN_OS with the current calendar? %$',
                   0, 0);
      discard(term_$read(1, input, 6, st));
      if (input[1] = 'Y') or else (input[1] = 'y') then
        return;
    until (input[1] = 'N') or else (input[1] = 'n');
    vfmt_$write2('%/Please set the calendar using the offline CALENDAR program.%.',
                 0, 0);
    status_ret.all := cal_$refused;
  end;

  cal_$verify := false;
end;
