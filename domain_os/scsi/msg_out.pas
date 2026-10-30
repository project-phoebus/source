{ scsi_msg_out - send the message out phase's bytes.

  Image addresses:
    sau9  0x3C4A5D80  scsi_msg_out

  Assume we're called with the SCSI spin lock held.

  - The driver's own message (an ABORT or a BUS DEVICE RESET) when one
    is pending, else the bus's message; a reset makes the target
    asynchronous and to be negotiated again.
}

procedure scsi_msg_out(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                       req: scsi_req_ptr_t); internal;
var
  regs: c90_regs_ptr_t;
  i: integer;
begin
  regs := cb^.regs;
  if tgt^.msg_out_state <> scsi_mo_none then begin
    if tgt^.msg_out_code = scsi_msg_bus_device_reset then begin
      tgt^.sync_period := 5;
      tgt^.sync_offset := 0;
      tgt^.sync_state := scsi_sync_none;
    end;
    tgt^.msg_out_state := scsi_mo_sent;
    regs^.fifo := tgt^.msg_out_code;
  end
  else
    for i := 0 to cb^.msg_count - 1 do
      regs^.fifo := cb^.msg[i];
  regs^.cmd := c90_cmd_transfer_info;
  tgt^.state := scsi_ts_msg_out;
end;
