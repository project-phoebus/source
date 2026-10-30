{ DISK_$GET_ERROR_INFO - hand out the last disk error record.

  Image addresses:
    sau2  0x00E6C08C  DISK_$GET_ERROR_INFO

  - DISK_$ERROR_INFO (disk/disk.pas's) copied whole into the caller's
    buffer.

  Status stored: none.
}

procedure disk_$get_error_info(out buffer: disk_$error_info_t);
begin
  buffer := disk_$error_info;
end;
