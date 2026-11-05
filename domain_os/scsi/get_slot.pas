{ scsi_get_slot - take a free slot of a device's bus for a command.

  Image addresses:
    sau7  0x3C4B80F6  scsi_get_slot (module-local)

  - The first slot of 0..scsi_mb_last_free_slot not in use; its outgoing
    mailbox is marked taken (scsi_mb_slot_taken).
  - Returns the slot's number, -1 when none is free.

  Status stored: none.
}

function scsi_get_slot(var t: scsi_tinfo_t): integer; internal;
var
  cb: scsi_mb_cb_ptr_t;
  i: integer;
  slot: integer;
begin
  slot := -1;
  cb := addr(scsi_$cb[t.bus]);
  for i := 0 to scsi_mb_last_free_slot do
    if not (scsi_slot_in_use in cb^.slots[i].flags) then begin
      slot := i;
      scsi_mailboxes[i].status := scsi_mb_slot_taken;
      exit;
    end;
  scsi_get_slot := slot;
end;
