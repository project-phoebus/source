{ DISK_$READ_MFG_BADSPOTS - read a volume's manufacturer's bad-spot page.

  Image addresses:
    sau2  0x00E6B7E4  DISK_$READ_MFG_BADSPOTS

  - The page is checked and wired by AS_IO_SETUP; DISK_IO operation 4
    reads the block into it; the page is unwired.

  Status stored:
    disk_io's result: the read (a block header error as status_$ok)
    as_io_setup's status: the page could not be wired
}

procedure disk_$read_mfg_badspots(vol_idx: integer; daddr: linteger;
                                  var buffer: univ disk_$page_t;
                                  out status: status_$t);
var
  wired: integer32;
  info: disk_$info_t;
begin
  wired := as_io_setup(vol_idx, addr(buffer), status);
  if status.code <> 0 then
    return;

  info[1] := 0;
  status.all := disk_io(disk_$io_read_badspots, vol_idx, wired, daddr, info);
  if status.all = status_$disk_block_header_error then
    status.all := status_$ok;

  wp_$unwire(wired);
end;
