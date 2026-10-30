%if ct_scsi %then
{ CT_$WAIT - wait for the outstanding tape operation to end.

  Image addresses:
    sau9  0x3C4783F6  ct_scsi_wait_op (nested)
    sau9  0x3C47848A  CT_$WAIT

  - For a drive with a command outstanding, SCSI_WAIT waits, the
    time-out in seconds (a negative time-out stands for 8000 seconds);
    the count is the command's count, or 0 when it failed.
  - With nothing outstanding the count is not stored; without a drive
    that is set up, nothing is stored.

  Status stored:
    status_$ok: nothing was outstanding
    SCSI_WAIT's result: the operation ended, or not
    ct_check_unit's result: the unit may not be used ("operation in
      progress" excepted)
}

procedure ct_$wait(in unit: integer; in timeout: integer;
                   out count: integer; out status: status_$t);
var
  ms: integer32;

  { ct_scsi_wait_op - wait for a drive that is set up. }
  procedure ct_scsi_wait_op;
  begin
    status.all := ct_check_unit(unit);
    if status.all = 0 then
      return;
    if status.all = status_$ct_operation_in_progress then
      status.all := 0
    else if status.all <> 0 then
      return;
    if timeout < 0 then
      ms := ct_scsi_long_timeout
    else
      ms := timeout * 1000;
    status.all := scsi_wait(ms, true);
    if status.all = 0 then
      count := ct_xfer_count
    else
      count := 0;
  end;

begin
  if ct_scsi_state = ct_scsi_present then
    ct_scsi_wait_op;
end;
%else
{ CT_$WAIT - wait for the outstanding tape operation to end.

  Image addresses:
    sau5  0x00E77B7E  CT_$WAIT

  - CT_WAIT waits, quit allowed, for the time-out in quarter ticks (a
    negative time-out stands for 32000 ticks).  The count of blocks done
    is the command's count less the count the controller left.

  Status stored:
    ct_wait's result: the operation ended, or not
    ct_check_unit's result: the unit may not be used ("operation in
      progress" excepted)
}

procedure ct_$wait(in unit: integer; in timeout: integer;
                   out count: integer; out status: status_$t);
var
  ticks: integer32;
begin
  status.all := ct_check_unit(unit);
  if status.all = status_$ct_operation_in_progress then
    status.all := 0
  else if status.all <> 0 then
    return;
  if timeout < 0 then
    ticks := 32000
  else
    ticks := integer32(timeout) * 4;
  status.all := ct_wait(ticks, true);
  count := ct_count - ct_regs^.count;
end;
%endif
