{ LPR_$RELEASE - release the line printer.

  Image addresses:
    sau3  0x00E6EA44  LPR_$RELEASE

  - Without the driver hand assembly (lpr/m68k/release.s): this
    fragment is the driver's.
  - For the process that acquired the printer.  With wait, the queued
    lines are waited for in steps of 2 times 65536 ticks (a quit ends
    it, the printer still acquired); then the port's interrupt is
    disabled and the driver unwired.

  Status stored:
    status_$ok: the printer was released
    status_$lpr_not_acquired: the caller did not acquire the printer
    time_$wait's status: a quit ended the wait
}

procedure lpr_$release(in wait: boolean; out status_ret: status_$t);
var
  delay: time_$clock_t;
  i: integer;
begin
  if proc1_$current <> lpr_owner then begin
    status_ret.all := status_$lpr_not_acquired;
    return;
  end;
  delay.high := 2;
  delay.low := 0;
  if wait then
    while lpr_$bcb.read <> lpr_$bcb.write do begin
      time_$wait(time_$relative, delay, status_ret);
      if status_ret.all = time_$wait_quit then
        return;
    end;
  lpr_$disable_int;
  for i := 1 to lpr_wire_count do
    wp_$unwire(lpr_wire_list[i]);
  lpr_owner := 0;
  lpr_acquired := false;
  status_ret.all := status_$ok;
end;
