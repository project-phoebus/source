{ scsi_enable_select - let targets reselect the controller.

  Image addresses:
    sau9  0x3C4A61EA  scsi_enable_select

  Assume we're called with the SCSI spin lock held.
}

procedure scsi_enable_select(cb: scsi_cb_ptr_t);
begin
  cb^.regs^.cmd := c90_cmd_enable_select;
end;
