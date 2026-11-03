{ LPR_$RELEASE - release the line printer.

  Image addresses:
    sau3  0x00E6EA44  LPR_$RELEASE
    sau4  0x0F87B878  LPR_$RELEASE

  - Without the driver hand assembly (lpr/m68k/release.s): this
    fragment is the driver's.
  - For the process that acquired the printer.  With wait, the queued
    lines are waited for in steps of 2 times 65536 ticks (a quit ends
    it, the printer still acquired); then the port's interrupt is
    disabled and the driver unwired.
  - The PNA form sets the printer's PBU unit down (PBU_$RELEASE_INT).

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
%if lpr_pbu_unit %then
  if lpr_owner <> proc1_$current then begin
%else
  if proc1_$current <> lpr_owner then begin
%endif
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
%if lpr_pbu_unit %then
  pbu_$release_int(lpr_pbu_unit_number, lpr_release_mode, status_ret);
%else
  lpr_$disable_int;
%endif
  for i := 1 to lpr_wire_count do
    wp_$unwire(lpr_wire_list[i]);
  lpr_owner := 0;
  lpr_acquired := false;
  status_ret.all := status_$ok;
end;
