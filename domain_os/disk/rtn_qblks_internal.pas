{ disk_$rtn_qblks_internal - give a chain of queue blocks back.

  Image addresses:
    sau2  0x00E3C01A  disk_$rtn_qblks_internal

  - Under the queue blocks' lock the reserved block is marked available
    again; any other chain goes in front of the free list, and the
    ring's waiters whose counts now fit are served in turn.

  Status stored: none.
}

procedure disk_$rtn_qblks_internal(count: integer; first: disk_$io_req_ptr_t;
                                   last: disk_$io_req_ptr_t);
  internal;
begin
  ml_$exclusion_start(disk_$exclusion);

  if first = disk_$reserve_block then begin
    { the reserved block }
    disk_$reserve_avail := true;
    if disk_$pending_count = 0 then
      ec_$advance(disk_$ec);
  end
  else begin
    { back on the free list, then the ring }
    last^.free_next := disk_$free_head;
    disk_$free_head := first;
    disk_$nfblks := disk_$nfblks + count;
    while (disk_$pending_count > 0) and then
          (disk_$req_queue[disk_$req_read_idx] <= disk_$nfblks) do begin
      disk_$nfblks := disk_$nfblks - disk_$req_queue[disk_$req_read_idx];
      disk_$pending_count := disk_$pending_count - 1;
      ec_$advance(disk_$ec);
      if disk_$req_read_idx = 64 then
        disk_$req_read_idx := 1
      else
        disk_$req_read_idx := disk_$req_read_idx + 1;
    end;
  end;

  ml_$exclusion_stop(disk_$exclusion);
end;
