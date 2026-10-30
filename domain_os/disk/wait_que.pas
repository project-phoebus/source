{ DISK_$WAIT_QUE - wait for the current process's queued I/O.

  Image addresses:
    sau2  0x00E3CABA  DISK_$WAIT_QUE

  - disk_$wait_io with the caller's arguments.

  Status stored: none.
}

procedure disk_$wait_que(disk_mask: disk_$vol_set_t; var io_wait_val: integer32;
                         var error_wait_val: integer32);
begin
  disk_$wait_io(disk_mask, io_wait_val, error_wait_val);
end;
