{ MT_$WIRE - wire a user buffer for transfers on a tape unit.

  Image addresses:
    sau3  0x00E70F1C  MT_$WIRE
    sau4  0x0F87DC8C  MT_$WIRE
    sau5  0x00E76A8C  MT_$WIRE
    sau6  0x7807D72C  MT_$WIRE

  Status stored:
    mt_$queue_request's status: the unit's check failed
    status_$ok: the buffer was wired
    status_$mt_buffer_already_wired: it is wired already (no fail bit)
    pbu2_$wire's status, its fail bit set: any other failure
}

procedure mt_$wire;
var
  u: integer;
begin
  u := unit;
  mt_$queue_request(u, mt_op_check, 0, 0, 0, status);
  if status.all = 0 then begin
    pbu2_$wire(mt_$scb.units[u].pbu_unit, buffer, length, status);
    status.fail := false;
    if status.all = status_$pbu_page_already_wired then
      status.all := status_$mt_buffer_already_wired
    else if status.all <> 0 then
      status.fail := true;
  end;
end;
