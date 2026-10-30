{ FILE_$SET_DTM - set an object's time of last modification, whole.

  Image addresses:
    sau2  0x00E5E28E  FILE_$SET_DTM

  - The high part given, with no fraction, goes to FILE_$SET_DTM_F with
    the flag false (the time given, not the current one).

  Status stored:
    file_$set_dtm_f's status: in either case
}

procedure file_$set_dtm(in file_uid: uid_$t; in time_value: time_$clockh_t;
                        out status_ret: status_$t);
var
  clock: time_$clock_t;
begin
  clock.high := time_value;
  clock.low := 0;

  file_$set_dtm_f(file_uid, false, clock, status_ret);
end;
