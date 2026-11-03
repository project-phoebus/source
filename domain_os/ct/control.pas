%if ct_scsi %then
{ CT_$CONTROL - perform a tape motion or control operation.

  Image addresses:
    sau9  0x3C478018  ct_scsi_control_op (nested)
    sau9  0x3C47818A  CT_$CONTROL

  - Only for a drive that is set up; the operation is started, not
    waited for (CT_$WAIT).
  - ct_$op_load starts nothing: it answers whether a transfer is under
    way, then waits for the tape's block address (at the load point a
    warning) and the write protection.
  - The spacing and filemark operations take a count of 1..32, the others
    count 1; ct_scsi_control answers an unknown operation.
  - The frame holds the QIC-02 arm's locals, cmd, write_ok and counted
    (the SAU5's; the SAU7's copy keeps its command word at -8), which
    this arm does not use.

  Status stored:
    status_$ok: the operation was started, or (load) the tape may be
      written
    ct_check_unit's result: the unit may not be used
    status_$ct_operation_in_progress: (load) a command is outstanding
    status_$ct_tape_in_read_mode or status_$ct_tape_in_write_mode: (load)
      a transfer is under way
    status_$ct_tape_at_load_point: (load) a warning
    status_$ct_tape_write_protected: (load) the tape is write protected
    status_$ct_invalid_operation_count: a count outside 1..32
    ct_scsi_control's or SCSI_WAIT's result: those failed
}

procedure ct_$control(in unit: integer; in op: integer; in count: integer;
                      out status: status_$t);
var
  cmd: integer;                           { the QIC-02 arm's }
  write_ok: boolean;                      { the QIC-02 arm's }
  counted: boolean;                       { the QIC-02 arm's }

  { ct_scsi_control_op - the operation, on a drive that is set up. }
  procedure ct_scsi_control_op;
  var
    counted: boolean;
    at_bot: boolean;
  begin
    if op = ct_$op_load then begin
      if ct_busy then
        status.all := status_$ct_operation_in_progress
      else if ct_io_state = ct_state_read then
        status.all := status_$ct_tape_in_read_mode
      else if ct_io_state = ct_state_write then
        status.all := status_$ct_tape_in_write_mode
      else begin
        status.all := ct_scsi_control(ct_op_block_address, 1);
        if status.all = 0 then
          status.all := scsi_wait(ct_scsi_timeout, true);
        if status.all <> 0 then
          return;
        at_bot := ct_from_24(ct_mode.g.addr) = 1;
        if at_bot then begin
          status.all := status_$ct_tape_at_load_point;
          return;
        end;
        status.all := ct_scsi_control(ct_op_mode_sense, 1);
        if status.all = 0 then
          status.all := scsi_wait(ct_scsi_timeout, true);
        if (status.all = 0) and then ct_mode.f.wp then
          status.all := status_$ct_tape_write_protected;
      end;
    end
    else begin
      counted := false;
      case op of
        ct_$op_space_fwd, ct_$op_space_rev, ct_$op_file_fwd,
        ct_$op_file_rev, ct_$op_write_filemark:
          counted := true;
      end;
      if counted
         and then ((count <= 0) or else (count > ct_max_op_count)) then
      begin
        status.all := status_$ct_invalid_operation_count;
        return;
      end;
      if counted then
        status.all := ct_scsi_control(op, count)
      else
        status.all := ct_scsi_control(op, 1);
    end;
  end;

begin
  status.all := ct_check_unit(unit);
  if (status.all = 0) and then (ct_scsi_state = ct_scsi_present) then
    ct_scsi_control_op;
end;
%elseif ct_atbus_qic02 %then
{ CT_$CONTROL - perform a tape motion or control operation.

  Image addresses:
    sau8  0x03C7AF6E  CT_$CONTROL

  - The operation (ct/ct.ins.pas's ct_$op_ constants) chooses the
    command, the direction, whether the count applies, and whether the
    tape is writable afterwards.  A load reads the drive's status
    instead (960 ticks' wait with quit), with the AT bus adapter
    (`ct_atbus_qic02').
  - The file spacing forward and a filemark set ct_restart; a rewind
    first resets the adapter when ct_restart is clear (it must give
    "tape power on/reset"), and clears ct_eot_seen; the reset operation
    resets the adapter and waits for it (960 ticks with quit).
  - The command is started with DO_CTL_CMD and not waited for (CT_$WAIT
    waits); when it starts, the writable mark takes the operation's
    value.

  Status stored:
    status_$ok: the command was started (or the load ended)
    ct_check_unit's, do_ctl_cmd's or ct_wait's result: those failed (the
      reset's: its end)
    status_$ct_tape_in_read_mode or status_$ct_tape_in_write_mode: a
      load during a transfer
    status_$ct_illegal_drive_command: a filemark where writing may not
      begin
    status_$ct_unrecognized_action_type: any other operation
    status_$ct_invalid_operation_count: a count outside 1..32
}

procedure ct_$control(in unit: integer; in op: integer; in count: integer;
                      out status: status_$t);
var
  cmd: integer;
  write_ok: boolean;
  counted: boolean;
begin
  status.all := ct_check_unit(unit);
  if status.all <> 0 then
    return;
  write_ok := ct_write_ok;
  counted := false;
  case op of
    ct_$op_load: begin
      case ct_state of
        ct_state_none: begin
            ct_reading := true;
            status.all := do_ctl_cmd(ct_cmd_read_status, 1);
            if status.all <> 0 then
              return;
            status.all := ct_wait(960, true);
            return;
          end;
        ct_state_read: begin
            status.all := status_$ct_tape_in_read_mode;
            return;
          end;
        ct_state_write: begin
            status.all := status_$ct_tape_in_write_mode;
            return;
          end;
      end;
    end;
    ct_$op_space_fwd: begin
        ct_reading := true;
        cmd := ct_cmd_space_fwd;
        counted := true;
        write_ok := false;
      end;
    ct_$op_space_rev: begin
        ct_reading := true;
        cmd := ct_cmd_space_rev;
        counted := true;
        write_ok := false;
      end;
    ct_$op_file_fwd: begin
        ct_reading := true;
        cmd := ct_cmd_file_fwd;
        write_ok := false;
        counted := true;
        ct_restart := true;
      end;
    ct_$op_file_rev: begin
        ct_reading := true;
        cmd := ct_cmd_file_rev;
        counted := true;
        write_ok := false;
      end;
    ct_$op_write_filemark: begin
        if not ct_write_ok then begin
          status.all := status_$ct_illegal_drive_command;
          return;
        end;
        cmd := ct_cmd_write_filemark;
        ct_reading := false;
        counted := true;
        ct_restart := true;
      end;
    ct_$op_erase: begin
        cmd := ct_cmd_erase;
        ct_reading := false;
        write_ok := true;
      end;
    ct_$op_retension: begin
        cmd := ct_cmd_retension;
        ct_reading := true;
        write_ok := true;
      end;
    ct_$op_rewind: begin
        if not ct_restart then begin
          reset_drive;
          status.all := ct_wait(960, false);
          if status.all <> status_$ct_tape_power_on_reset then
            return;
          status.all := 0;
          ct_restart := true;
        end;
        ct_eot_seen := false;
        ct_reading := true;
        cmd := ct_cmd_rewind;
        write_ok := true;
      end;
    ct_$op_reset: begin
        reset_drive;
        status.all := ct_wait(960, true);
        ct_write_ok := false;
        return;
      end;
    otherwise begin
        status.all := status_$ct_unrecognized_action_type;
        return;
      end;
  end;

  if counted then
    if (count <= 0) or else (count > 32) then begin
      status.all := status_$ct_invalid_operation_count;
      return;
    end;
  if counted then
    status.all := do_ctl_cmd(cmd, count)
  else
    status.all := do_ctl_cmd(cmd, 1);
  if status.all = 0 then
    ct_write_ok := write_ok;
end;
%else
{ CT_$CONTROL - perform a tape motion or control operation.

  Image addresses:
    sau5  0x00E77850  CT_$CONTROL

  - The operation (ct/ct.ins.pas's ct_$op_ constants) chooses the
    command, the direction, whether the count applies, and whether the
    tape is writable afterwards.  A load waits 960 ticks with quit.
  - The command is started with DO_CTL_CMD and not waited for (CT_$WAIT
    waits); when it starts, the writable mark takes the operation's
    value.

  Status stored:
    status_$ok: the command was started (or the load ended)
    ct_check_unit's, do_ctl_cmd's or ct_wait's result: those failed
    status_$ct_tape_in_read_mode or status_$ct_tape_in_write_mode: a
      load during a transfer
    status_$ct_illegal_drive_command: a filemark where writing may not
      begin
    status_$ct_unrecognized_action_type: any other operation
    status_$ct_invalid_operation_count: a count outside 1..32
}

procedure ct_$control(in unit: integer; in op: integer; in count: integer;
                      out status: status_$t);
var
  cmd: integer;
  write_ok: boolean;
  counted: boolean;
begin
  status.all := ct_check_unit(unit);
  if status.all <> 0 then
    return;
  write_ok := ct_write_ok;
  counted := false;
  case op of
    ct_$op_load: begin
      case ct_state of
        ct_state_none: begin
            ct_reading := true;
            status.all := do_ctl_cmd(ct_cmd_load, 1);
            if status.all <> 0 then
              return;
            status.all := ct_wait(960, true);
            return;
          end;
        ct_state_read: begin
            status.all := status_$ct_tape_in_read_mode;
            return;
          end;
        ct_state_write: begin
            status.all := status_$ct_tape_in_write_mode;
            return;
          end;
      end;
    end;
    ct_$op_space_fwd: begin
        ct_reading := true;
        cmd := ct_cmd_space_fwd;
        counted := true;
        write_ok := false;
      end;
    ct_$op_space_rev: begin
        ct_reading := true;
        cmd := ct_cmd_space_rev;
        counted := true;
        write_ok := false;
      end;
    ct_$op_file_fwd: begin
        ct_reading := true;
        cmd := ct_cmd_file_fwd;
        write_ok := false;
        counted := true;
      end;
    ct_$op_file_rev: begin
        ct_reading := true;
        cmd := ct_cmd_file_rev;
        counted := true;
        write_ok := false;
      end;
    ct_$op_write_filemark: begin
        if not ct_write_ok then begin
          status.all := status_$ct_illegal_drive_command;
          return;
        end;
        cmd := ct_cmd_write_filemark;
        ct_reading := false;
        counted := true;
      end;
    ct_$op_erase: begin
        cmd := ct_cmd_erase;
        ct_reading := false;
        write_ok := true;
      end;
    ct_$op_retension: begin
        cmd := ct_cmd_retension;
        ct_reading := true;
        write_ok := true;
      end;
    ct_$op_rewind: begin
        ct_reading := true;
        cmd := ct_cmd_rewind;
        write_ok := true;
      end;
    ct_$op_reset: begin
        cmd := ct_cmd_reset;
        ct_reading := true;
        write_ok := false;
      end;
    otherwise begin
        status.all := status_$ct_unrecognized_action_type;
        return;
      end;
  end;

  if counted then
    if (count <= 0) or else (count > 32) then begin
      status.all := status_$ct_invalid_operation_count;
      return;
    end;
  if counted then
    status.all := do_ctl_cmd(cmd, count)
  else
    status.all := do_ctl_cmd(cmd, 1);
  if status.all = 0 then
    ct_write_ok := write_ok;
end;
%endif
