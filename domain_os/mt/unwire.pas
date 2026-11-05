{ MT_$UNWIRE - unwire a user buffer the driver had wired for a tape
  unit.

  Image addresses:
    sau3  0x00E70D78  MT_$UNWIRE
    sau4  0x0F87DAF0  MT_$UNWIRE
    sau5  0x00E768E2  MT_$UNWIRE
    sau6  0x7807D58E  MT_$UNWIRE

  - Each page is touched as it is unwired.

  Status stored:
    mt_$queue_request's status: the unit's check failed
    pbu2_$unwire's status, its fail bit set when not ok: the buffer was
      unwired, or not
}

procedure mt_$unwire;
var
  u: integer;
begin
  u := unit;
  mt_$queue_request(u, mt_op_check, 0, 0, 0, status);
  if status.all = 0 then begin
    pbu2_$unwire(mt_$scb.units[u].pbu_unit, buffer, length, true, status);
    status.fail := status.all <> 0;
  end;
end;
