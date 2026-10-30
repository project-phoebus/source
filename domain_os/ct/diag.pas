%if ct_scsi %then
{ CT_$DIAG - return diagnostic information about the tape controller.

  Image addresses:
    sau9  0x3C4781C6  ct_scsi_diag (nested)
    sau9  0x3C478252  CT_$DIAG

  - The caller's buffer is cleared; for a drive that is set up, by the
    mode (the ct_$diag_ constants): the drive's self-test is run (10
    seconds' wait) and the last command's status code returned, or the
    drive's sense is taken and its word at byte 22 returned.

  Status stored:
    status_$ok: the information was returned
    ct_check_unit's result: the unit may not be used
    ct_scsi_control's, SCSI_WAIT's or ct_request_sense's result: those
      failed
    status_$ct_unrecognized_action_type: any other mode
}

procedure ct_$diag(in unit: integer; in mode: integer;
                   out buf: univ ct_$diag_buf_t; in buf_len: integer;
                   out ret_len: integer; out status: status_$t);
var
  i: integer;

  { ct_scsi_diag - the mode's information, from a drive that is set
    up. }
  procedure ct_scsi_diag;
  begin
    case mode of
      ct_$diag_drive_status: begin
          status.all := ct_scsi_control(ct_op_self_test, 1);
          if status.all = 0 then
            status.all := scsi_wait(ct_scsi_timeout, true);
          buf[1] := ct_last_status.code;
          ret_len := 2;
        end;
      ct_$diag_counts: begin
          status.all := ct_request_sense;
          buf[1] := ct_sense.w[11];
          buf[2] := 0;
          ret_len := 4;
        end;
      otherwise begin
        status.all := status_$ct_unrecognized_action_type;
      end;
    end;
  end;

begin
  if buf_len > 0 then
    for i := 1 to buf_len div 2 do
      buf[i] := 0;
  ret_len := 0;
  status.all := ct_check_unit(unit);
  if (status.all = 0) and then (ct_scsi_state = ct_scsi_present) then
    ct_scsi_diag;
end;
%else
{ CT_$DIAG - return diagnostic information about the tape controller.

  Image addresses:
    sau5  0x00E779CC  CT_$DIAG

  - The caller's buffer is cleared; by the mode (the ct_$diag_
    constants) it gets the drive's status word, the controller's first
    256 register words (as many as fit), or CT_$DIAG's two counts.
  - In the last case the counts are then cleared.

  Status stored:
    status_$ok: the information was returned
    ct_check_unit's result: the unit may not be used
    status_$ct_unrecognized_action_type: any other mode
}

procedure ct_$diag(in unit: integer; in mode: integer;
                   out buf: univ ct_$diag_buf_t; in buf_len: integer;
                   out ret_len: integer; out status: status_$t);
var
  i: integer;
  n: integer;
begin
  if buf_len > 0 then
    for i := 1 to buf_len div 2 do
      buf[i] := 0;
  ret_len := 0;
  status.all := ct_check_unit(unit);
  if status.all <> 0 then
    return;
  with ct_regs^ do
    case mode of
      ct_$diag_drive_status: begin
          buf[1] := dstat;
          ret_len := 2;
        end;
      ct_$diag_registers: begin
          n := (integer32(addr(words_end)) - integer32(ct_regs)) div 2;
          if buf_len div 2 < n then
            n := buf_len div 2;
          for i := 1 to n do
            buf[i] := ct_regs^.words[i];
          ret_len := n + n;
        end;
      ct_$diag_counts: begin
          buf[1] := ct_total_2c;
          ct_total_2c := 0;
          buf[2] := ct_total_2e;
          ct_total_2e := 0;
          ret_len := 4;
        end;
      otherwise begin
        status.all := status_$ct_unrecognized_action_type;
      end;
    end;
end;
%endif
