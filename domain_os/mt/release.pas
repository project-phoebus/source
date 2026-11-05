{ MT_$RELEASE - release the magnetic tape.

  Image addresses:
    sau2  0x00E70A4C  MT_$RELEASE
    sau3  0x00E70B24  MT_$RELEASE
    sau4  0x0F87D89C  MT_$RELEASE
    sau5  0x00E7668E  MT_$RELEASE
    sau6  0x7807D33A  MT_$RELEASE

  - With the driver (`mt_driver', base/config.ins.pas), under the MT
    lock: the unit, or units 0 through 4 for -1, each given up when the
    check accepts it.  mode is not read.
  - On the SAU2 the driver is configured out and the routine does
    nothing.

  Status stored:
    mt_$queue_request's status: one unit was given up, or not
    status_$ok: unit is -1
    none: the driver is configured out
}

procedure mt_$release(in unit: integer; in mode: integer;
                      out status_ret: status_$t);
%if mt_driver %then
var
  u: integer;
  i: integer;
  first: integer;
  last: integer;
%endif
begin
%if mt_driver %then
  ml_$lock(ml_$mt_lock);
  if unit <> -1 then begin
    first := unit;
    last := first;
  end
  else begin
    first := 0;
    last := 4;
  end;
  for i := first to last do begin
    u := i;
    mt_$queue_request(u, mt_op_check, 0, 0, 0, status_ret);
    if status_ret.all = 0 then
      mt_$release_unit(i);
  end;
  if unit = -1 then
    status_ret.all := 0;
  ml_$unlock(ml_$mt_lock);
%endif
end;
