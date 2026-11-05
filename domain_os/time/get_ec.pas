{ TIME_$GET_EC - the level-2 handle of a clock eventcount.

  Image addresses:
    sau2  0x00E1670A  TIME_$GET_EC
    sau4  0x0F8170EA  TIME_$GET_EC
    sau6  0x78017186  TIME_$GET_EC
    sau7  0x3C418172  TIME_$GET_EC

  - The first call registers TIME_$CLOCKH_EC and TIME_$FAST_CLOCK_EC
    with EC2 and keeps their handles; key 0 gives the clock's handle, 1
    the fast clock's.

  Status stored:
    status_$ok: the handle was returned
    time_$bad_key: another key
    EC2_$REGISTER_EC1's status: a registration failed
}

procedure time_$get_ec(in key: integer; out ecp: ec2_$ptr_t;
                       out status: status_$t);
begin
  status.all := status_$ok;

  { register the two clocks once }
  if clock_ec_handle = nil then
    clock_ec_handle := ec2_$register_ec1(addr(time_$clockh_ec), status);
  if fast_clock_ec_handle = nil then
    fast_clock_ec_handle := ec2_$register_ec1(addr(time_$fast_clock_ec),
                                              status);

  if status.all = status_$ok then
    case key of
      time_$fast_clock_key: ecp := fast_clock_ec_handle;
      time_$clockh_key: ecp := clock_ec_handle;
      otherwise
        status.all := time_$bad_key;
    end;
end;
