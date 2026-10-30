{ FILE_$SET_DTU - set an object's time of last use from a high part.

  Image addresses:
    sau2  0x00E5E332  FILE_$SET_DTU

  - The 32-bit time given, a clock's high part with a zero low part, is
    set with FILE_$SET_DTU_F.

  Status stored:
    file_$set_dtu_f's status: in either case
}

procedure file_$set_dtu(in file_uid: uid_$t; in time_value: time_$clockh_t;
                        out status_ret: status_$t);
var
  clock: time_$clock_t;
begin
  clock.high := time_value;
  clock.low := 0;

  file_$set_dtu_f(file_uid, clock, status_ret);
end;
