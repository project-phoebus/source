{ DISK_$WRITE - write one block to a mounted volume.

  Image addresses:
    sau2  0x00E3CC78  DISK_$WRITE

  - DISK_IO writes the block (op 1).

  Status stored:
    disk_io's result: the write
    status_$volume_not_properly_mounted: the volume is not mounted
      (mount state 3)
}

procedure disk_$write(vol_idx: integer; daddr: integer32; ppn: integer32;
                      var info: univ disk_$info_t; out status: status_$t);
begin
  if disk_$dvtbl[vol_idx].mount_state <> 3 then
    status.all := status_$volume_not_properly_mounted
  else
    status.all := disk_io(disk_$io_write, vol_idx, ppn, daddr, info);
end;
