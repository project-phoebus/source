{ DISK_$AS_READ - read one block into a page, asynchronously addressed.

  Image addresses:
    sau2  0x00E6B860  DISK_$AS_READ

  - The page is checked and wired by AS_IO_SETUP and its first word
    touched; DISK_IO operation 2 reads the block and its header is
    handed back; the page is unwired.

  Status stored:
    disk_io's result: the read (a block header error as status_$ok)
    as_io_setup's status: the page could not be wired
}

procedure disk_$as_read(vol_idx: integer; daddr: linteger;
                        var buffer: univ disk_$page_t;
                        out info: disk_$info_t; out status: status_$t);
var
  wired: integer32;
  local_info: disk_$info_t;
begin
  wired := as_io_setup(vol_idx, addr(buffer), status);
  if status.code <> 0 then
    return;

  buffer[1] := buffer[1];

  local_info[1] := 0;
  status.all := disk_io(disk_$io_read_no_check, vol_idx, wired, daddr,
                        local_info);
  info := local_info;
  if status.all = status_$disk_block_header_error then
    status.all := status_$ok;

  wp_$unwire(wired);
end;
