{ DISK_$SHUTDOWN - shut a drive down through its driver.

  Image addresses:
    sau2  0x00E3DC28  DISK_$SHUTDOWN

  - The driver's shutdown entry, if it has one, is called with the
    entry's controller and the unit; its result is not used.

  Status stored: none.
}

procedure disk_$shutdown(in dev_info: disk_$device_entry_t; unit: integer);
begin
  if disk_$jump_table_ptr_t(dev_info.jump_table)^.shutdown <> nil then
    discard(disk_$shutdown_proc_t(
              disk_$jump_table_ptr_t(dev_info.jump_table)^.shutdown)^(
                dev_info.controller, unit));
end;
