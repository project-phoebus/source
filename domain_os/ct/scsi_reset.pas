{ ct_scsi_reset - reset the drive.

  Image addresses:
    sau7  0x3C484E0A  ct_scsi_reset (module-local)
    sau9  0x3C47752E  ct_scsi_reset (module-local)

  - SCSI_$RESET_DEVICE's status is kept in ct_reset_status; with
    `ct_reset_delay' a delay loop of 5000000 rounds gives the drive time
    to recover.
  - The next SCSI_WAIT answers the reset's status (ct_reset_pending);
    a command counts as outstanding until then, and the transfer state
    ends.

  Returns:
    SCSI_$RESET_DEVICE's status

  Status stored: none.
}

function ct_scsi_reset: integer32; internal;
var
  delay: integer32;
  i: integer32;
begin
  scsi_$reset_device(ct_handle, ct_reset_status);
%if ct_reset_delay %then
  for i := 1 to 5000000 do
    delay := delay + 1;
%endif
  ct_scsi_reset := ct_reset_status.all;
  ct_reset_pending := true;
  ct_busy := true;
  ct_io_state := ct_state_none;
end;
