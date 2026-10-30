{ DISK_$DO_IO - start a transfer through the volume's driver.

  Image addresses:
    sau2  0x00E3DAA2  DISK_$DO_IO

  - The volume's driver's do_io entry is called with the four arguments
    as they came.

  Status stored: none.
}

procedure disk_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
begin
  disk_$do_io_proc_t(disk_$jump_table_ptr_t(vol.dev_info^.jump_table)^.do_io)^(
    vol, req, param_3, result);
end;
