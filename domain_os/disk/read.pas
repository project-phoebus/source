{ DISK_$READ - read one block from a mounted or assigned volume.

  Image addresses:
    sau2  0x00E3CF64  DISK_$READ

  - DISK_IO reads the block (op 0).

  Status stored:
    disk_io's result: the read
    status_$volume_not_properly_mounted: neither mounted (state 3) nor
      assigned to the current process (state 1)
}

procedure disk_$read(vol_idx: integer; daddr: integer32; ppn: integer32;
                     var info: univ disk_$info_t; out status: status_$t);
begin
  with disk_$dvtbl[vol_idx] do
    if (mount_state <> 3) and then
       ((mount_state <> 1) or else (mount_proc <> proc1_$current)) then
      status.all := status_$volume_not_properly_mounted
    else
      status.all := disk_io(disk_$io_read, vol_idx, ppn, daddr, info);
end;
