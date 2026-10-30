{ scsi_xfer_pad - answer a data phase with no data to move.

  Image addresses:
    sau9  0x3C4A5E42  scsi_xfer_pad

  Assume we're called with the SCSI spin lock held.

  - The controller pads (or discards) up to 65535 bytes until the
    target leaves the data phase.
}

procedure scsi_xfer_pad(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                        req: scsi_req_ptr_t); internal;
var
  count: scsi_count_t;
  regs: c90_regs_ptr_t;
begin
  count.all := 0;
  count.lo := 16#FFFF;
  regs := cb^.regs;
  regs^.r18.sync.period := tgt^.sync_period;
  regs^.r1c.sync.offset := tgt^.sync_offset;
  regs^.tc_lo := count.b3;
  regs^.tc_hi := count.b2;
  regs^.cmd := c90_cmd_dma_transfer_pad;
  if req^.dir = scsi_$dir_out then
    tgt^.state := scsi_ts_data_out
  else
    tgt^.state := scsi_ts_data_in;
end;
