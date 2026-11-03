{ IIC_$NET_START - acquire a line for the network (the driver record's
  start).

  Image addresses:
    sau3  0x00E71AAA  IIC_$NET_START

  - The line is acquired with owner 0.  A line that started with a
    failed self test is released again.

  Status stored:
    iic_do_acquire's status: the line was started, or not
}

procedure iic_$net_start(in line: pinteger; out status: status_$t);
var
  st: status_$t;
begin
  iic_do_acquire(line, 0, status);
  if status.all = status_$iic_self_test_failure then
    iic_$release(line, st);
end;
