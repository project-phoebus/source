{ scsi_msg_in_start - start the message in phase.

  Image addresses:
    sau9  0x3C4A5DE6  scsi_msg_in_start

  Assume we're called with the SCSI spin lock held.

  - Within an extended message the next byte goes after the last; any
    other message starts the bus's buffer anew.
}

procedure scsi_msg_in_start(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                            req: scsi_req_ptr_t); internal;
begin
  cb^.regs^.cmd := c90_cmd_transfer_info;
  if (tgt^.state = scsi_ts_msg_in_more)
     and then (cb^.msg[0] = scsi_msg_extended) then
    cb^.msg_index := cb^.msg_index + 1
  else begin
    cb^.msg_count := 0;
    cb^.msg_index := 0;
  end;
  tgt^.state := scsi_ts_msg_in;
end;
