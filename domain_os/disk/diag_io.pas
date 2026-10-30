{ DISK_$DIAG_IO - a diagnostic transfer of one block.

  Image addresses:
    sau2  0x00E6BC18  DISK_$DIAG_IO

  - The caller's own page is used (wired, the cache flushed) when the
    volume is the caller's, or the block is 0 or in the volume, or a
    super user's read, or DISK_$DIAG is set.
  - Otherwise a read goes through a wired scratch page and a write is
    refused.
  - DISK_IO reads (op 0) or writes (op 1) the block; a read hands the
    header back.

  Status stored:
    disk_io's result: the transfer (a block header error as status_$ok)
    status_$invalid_volume_index: an index outside 1..10
    status_$operation_requires_a_physical_volume: a logical volume
    status_$disk_buffer_not_page_aligned: the caller's page is not one
    status_$volume_in_use: a refused write, or a scratch-page transfer
    mst_$wire's or wp_$calloc's status: the page could not be had
}

procedure disk_$diag_io(in op: integer; in vol_idx: integer;
                        in daddr: linteger; var buffer: univ disk_$page_t;
                        var info: disk_$info_t; out status: status_$t);
var
  wired: integer32;
  io_op: integer;
  local_info: disk_$info_t;
  own_page: boolean;
begin
  if not (vol_idx in [1..10]) then begin
    status.all := status_$invalid_volume_index;
    return;
  end;

  with disk_$dvtbl[vol_idx] do begin
    if lv_start <> 0 then begin
      status.all := status_$operation_requires_a_physical_volume;
      return;
    end;

    own_page := false;
    if ((mount_state = 2) and then (mount_proc = proc1_$current)) or else
       ((daddr = 0) and then (op = 0)) or else
       ((daddr >= addr_start) and then (daddr <= addr_end)) or else
       (acl_$is_suser and then (op = 0)) or else
       disk_$diag then
      own_page := true;
  end;

  if own_page then begin
    if (integer32(addr(buffer)) & 16#3FF) <> 0 then begin
      status.all := status_$disk_buffer_not_page_aligned;
      return;
    end;
    if op = 0 then
      buffer[1] := buffer[1] & buffer[1];
    wired := mst_$wire(integer32(addr(buffer)), status);
    cache_$flush_virtual;
  end
  else if op = 0 then
    wp_$calloc(wired, status)
  else
    status.all := status_$volume_in_use;

  if status.all <> status_$ok then
    return;

  if op = 1 then begin
    io_op := disk_$io_write_raw;
    local_info := info;
  end
  else begin
    io_op := disk_$io_read_no_check;
    local_info[1] := 0;
  end;

  status.all := disk_io(io_op, vol_idx, wired, daddr, local_info);
  if op = 0 then begin
    info := local_info;
    if status.all = status_$disk_block_header_error then
      status.all := status_$ok;
  end;

  if own_page then
    wp_$unwire(wired)
  else begin
    mmap_$free(wired);
    if status.all = status_$ok then
      status.all := status_$volume_in_use;
  end;
end;
