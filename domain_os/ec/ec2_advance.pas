{ EC2_$ADVANCE - advance a level-2 eventcount.

  Image addresses:
    sau2  0x00E42CAE  EC2_$ADVANCE

  - An address of 1000 or less is an EC2 number, not an eventcount.
    With a waiter ring recorded, EC2_$WAKEUP wakes the waiters reached.

  Status stored:
    status_$ok: the eventcount was advanced
    ec2_$wakeup's status: a waiter ring is recorded
    ec2_$bad_eventcount: the address is 1000 or less
}

procedure ec2_$advance(in out ecnt: ec2_$eventcount_t; out sts: status_$t);
var
  unused_4: integer32;                    { ec2_init.pas's TODO }
begin
  if linteger(addr(ecnt)) <= 1000 then
    sts.all := ec2_$bad_eventcount
  else begin
    sts.all := status_$ok;
    ecnt.value := ecnt.value + 1;
    if ecnt.awaiters <> 0 then
      ec2_$wakeup(ecnt, sts);
  end;
end;
