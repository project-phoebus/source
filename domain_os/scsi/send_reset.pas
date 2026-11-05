{ scsi_send_reset - reset a device through the host adapter and wait.

  Image addresses:
    sau7  0x3C4B81DC  scsi_send_reset (module-local)

  Assume we're called with scsi_$exclusion_lock held.

  - The two command bytes: the device reset and the target; kind 2
    also resets the bus.  The adapter's unsolicited report advances the
    device's reset eventcount, waited for 20 ticks with quit allowed,
    with the lock released.

  Status stored:
    status_$ok: the reset ended well
    the report's status: it ended
    status_$scsi_hardware_timeout: the command port was not ready
    status_$scsi_illegal_bus_revision: the adapter rejected a byte
    status_$scsi_operation_timeout: the report did not come in time
    status_$scsi_quit_fault: a quit
}

procedure scsi_send_reset(t: scsi_tinfo_ptr_t; kind: integer;
                          out status: status_$t); internal;
type
  cmd_t = record
    case integer of
      1: (b: array[0..1] of char);
      2: (f: packed record
            op: 0..255;                   { 0x00 }
            target: 0..7;                 { 0x01, bits 7..5 }
            unused_1: boolean;            { 0x01, bit 4 }
            bus_reset: boolean;           { 0x01, bit 3 }
            lun: 0..7;                    { 0x01, bits 2..0 }
          end);
  end;
var
  cb: scsi_mb_cb_ptr_t;
  regs: scsi_mb_regs_ptr_t;
  cmd: cmd_t;
  wait_value: integer32;
  quit_value: integer32;
  i: integer;
  which: integer;
begin
  status.all := status_$ok;
  cb := addr(scsi_$cb[t^.bus]);
  regs := cb^.regs;
  cmd.f.op := scsi_mb_cmd_reset_device;
  cmd.f.target := t^.target;
  cmd.f.lun := 0;
  cmd.f.bus_reset := kind = 2;
  wait_value := t^.reset_ec.value + 1;
  quit_value := fim_$quit_value[proc1_$as_id] + 1;
  for i := 0 to 1 do begin
    if scsi_wait_cmd_ready(cb^) then begin
      status.all := status_$scsi_hardware_timeout;
      return;
    end;
    regs^.cmd := ord(cmd.b[i]);
    if (regs^.cmd & scsi_mb_stat_rejected) <> 0 then begin
      status.all := status_$scsi_illegal_bus_revision;
      return;
    end;
  end;
  ml_$exclusion_stop(scsi_$exclusion_lock);
  which := ec_$wait(addr(t^.reset_ec), addr(time_$clockh_ec),
                    addr(fim_$quit_ec[proc1_$as_id]), wait_value,
                    time_$clockh + 20, quit_value);
  ml_$exclusion_start(scsi_$exclusion_lock);
  case which of
    0: begin
        status := t^.status;
      end;
    1: begin
        status.all := status_$scsi_operation_timeout;
      end;
    2: begin
        status.all := status_$scsi_quit_fault;
        fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
      end;
  end;
  if status.all = status_$ok then
    t^.flags := t^.flags - [scsi_tf_busy];
end;
