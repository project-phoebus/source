{ scsi_send_cdb - send the command phase's bytes.

  Image addresses:
    sau9  0x3C4A5FD6  scsi_send_cdb

  Assume we're called with the SCSI spin lock held.
}

procedure scsi_send_cdb(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                        req: scsi_req_ptr_t); internal;
var
  regs: c90_regs_ptr_t;
  i: integer;
begin
  regs := cb^.regs;
  regs^.cmd := c90_cmd_flush_fifo;
  regs^.r18.sync.period := tgt^.sync_period;
  regs^.r1c.sync.offset := tgt^.sync_offset;
  for i := 0 to req^.cdb_len - 1 do
    regs^.fifo := ord(req^.cdb.b[i]);
  regs^.cmd := c90_cmd_transfer_info;
  tgt^.state := scsi_ts_select;
end;
