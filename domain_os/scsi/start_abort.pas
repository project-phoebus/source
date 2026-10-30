{ scsi_start_abort - select a target to send the driver's own message.

  Image addresses:
    sau9  0x3C4A7010  scsi_start_abort

  Assume we're called with the SCSI spin lock held.

  - Selected with attention, stopping after the IDENTIFY, so that the
    message out phase follows (scsi_msg_out sends the message).
  - A target with nothing pending crashes the system.
}

procedure scsi_start_abort(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                           tid: integer); internal;
var
  req: scsi_req_ptr_t;
  regs: c90_regs_ptr_t;
begin
  req := tgt^.pend_head;
  if req = nil then
    crash_system(status_$scsi_internal_error);
  regs := cb^.regs;
  regs^.cmd := c90_cmd_flush_fifo;
  regs^.r10.dest.id := tid;
  regs^.r14.sel_timeout := cb^.sel_timeout;
  regs^.r18.sync.period := tgt^.sync_period;
  regs^.r1c.sync.offset := tgt^.sync_offset;
  regs^.fifo := scsi_msg_identify_disc ! req^.cdb.f.lun;
  regs^.cmd := c90_cmd_select_atn_stop;
  cb^.connected := true;
  cb^.cur_target := tid;
  cb^.disc_pending := false;
  tgt^.active := true;
  tgt^.state := scsi_ts_select;
  tgt^.last_msg[0] := scsi_msg_nop;
  tgt^.last_msg_len := 1;
end;
