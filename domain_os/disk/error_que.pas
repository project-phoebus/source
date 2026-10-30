{ DISK_$ERROR_QUE - ask the volume's driver about an error or a timeout.

  Image addresses:
    sau2  0x00E3DAD4  DISK_$ERROR_QUE

  - The volume's driver's error_que entry is called with the volume,
    the timeout word and the result flag.

  Status stored: none.
}

procedure disk_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                          out result: boolean);
begin
  disk_$error_que_proc_t(
    disk_$jump_table_ptr_t(vol.dev_info^.jump_table)^.error_que)^(
      vol, is_timeout, result);
end;
