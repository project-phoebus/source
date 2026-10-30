{ DISK_$AS_WRITE - write one page to a block, asynchronously addressed.

  Image addresses:
    sau2  0x00E6B8EA  DISK_$AS_WRITE

  - The page is checked and wired by AS_IO_SETUP; DISK_IO operation 1
    writes it with a local copy of the caller's header; the page is
    unwired.

  Status stored:
    disk_io's result: the write
    as_io_setup's status: the page could not be wired
}

procedure disk_$as_write(vol_idx: integer; daddr: linteger;
                         var buffer: univ disk_$page_t;
                         in info: disk_$info_t; out status: status_$t);
var
  wired: integer32;
  local_info: disk_$info_t;
begin
  wired := as_io_setup(vol_idx, addr(buffer), status);
  if status.code <> 0 then
    return;

  local_info := info;
  status.all := disk_io(disk_$io_write, vol_idx, wired, daddr, local_info);

  wp_$unwire(wired);
end;
