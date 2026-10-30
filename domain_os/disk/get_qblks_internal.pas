{ disk_$get_qblks_internal - take count queue blocks from the pool.

  Image addresses:
    sau2  0x00E3BE8A  disk_$get_qblks_internal

  - Under the queue blocks' lock the free blocks are taken when they
    suffice and the caller may jump the queue (mode) or nobody waits;
    else the pool is grown, while allowed and not for a type-5 process.
  - Failing that, a caller in mode takes the reserved block or waits;
    any other queues its count in the ring and waits its turn.
  - The blocks are stamped (status ok, the current process the owner)
    and chained; the chain's ends are returned.

  Status stored: none.
}

procedure disk_$get_qblks_internal(count: integer; mode: boolean;
                                   out first_out: disk_$io_req_ptr_t;
                                   out last_out: disk_$io_req_ptr_t);
  internal;
label
  10, 20;
var
  wait_val: integer32;
  i: integer;
begin
  ml_$exclusion_start(disk_$exclusion);

  { enough free blocks, and the caller may take them }
10:
  if (count <= disk_$nfblks) and then
     (mode or else (disk_$pending_count = 0)) then begin
    disk_$nfblks := disk_$nfblks - count;
    goto 20;
  end;

  { grow the pool and try again }
  if ((not disk_$alloc_disabled) and (disk_$pending_count = 0)) and then
     (proc1_$type[proc1_$current] <> 5) then begin
    discard(disk_$grow_qblk_pool(count));
    goto 10;
  end;

  { the reserved block, or wait }
  if mode then begin
    if disk_$reserve_avail then begin
      disk_$free_head := disk_$reserve_block;
      disk_$reserve_avail := false;
      goto 20;
    end;
    wait_val := disk_$ec.value + 1;
  end
  else begin
    disk_$req_queue[disk_$req_write_idx] := count;
    if disk_$req_write_idx = 64 then
      disk_$req_write_idx := 1
    else
      disk_$req_write_idx := disk_$req_write_idx + 1;
    disk_$pending_count := disk_$pending_count + 1;
    wait_val := disk_$pending_count + disk_$ec.value;
  end;

  ml_$exclusion_stop(disk_$exclusion);
  discard(ec_$wait(addr(disk_$ec), addr(ec_$nil_ec), addr(ec_$nil_ec),
                   wait_val, 0, 0));
  ml_$exclusion_start(disk_$exclusion);
  if mode then
    goto 10;

  { take the blocks }
20:
  first_out := disk_$free_head;
  for i := 1 to count do begin
    disk_$free_head^.status.all := status_$ok;
    disk_$free_head^.flags := 0;
    disk_$free_head^.owner_op.owner := proc1_$current;
    disk_$free_head^.owner_op.all := 0;
    if i = count then
      last_out := disk_$free_head;
    disk_$free_head^.next := disk_$free_head^.free_next;
    disk_$free_head := disk_$free_head^.free_next;
  end;
  last_out^.free_next := nil;
  last_out^.next := nil;

  ml_$exclusion_stop(disk_$exclusion);
end;
