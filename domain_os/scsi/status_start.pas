{ scsi_status_start - start the status phase.

  Image addresses:
    sau9  0x3C4A5E24  scsi_status_start

  Assume we're called with the SCSI spin lock held.

  - The controller takes the status byte and the message after it.
}

procedure scsi_status_start(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                            req: scsi_req_ptr_t); internal;
begin
  cb^.regs^.cmd := c90_cmd_command_complete;
  tgt^.state := scsi_ts_status;
end;
