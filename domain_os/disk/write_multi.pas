{ DISK_$WRITE_MULTI - write a chain of requests, a volume at a time.

  Image addresses:
    sau2  0x00E3CCEE  DISK_$WRITE_MULTI

  - The chain is written a run of same-volume requests at a time: with
    NETLOG on, a checksumming device or one without queued writes, a
    request at a time through DISK_IO; else mapped and handed to the
    drivers.  Failed requests go to disk_$io_error.

  Status stored:
    status_$ok: the chain was written (each request has its own status)
    disk_$map_request's status: a run could not be mapped
}

procedure disk_$write_multi(all_mounted: boolean; req_list: disk_$io_req_ptr_t;
                            out status: status_$t);
var
  map: disk_$vol_map_t;
  err_wait: integer32;
  io_wait: integer32;
  cur: disk_$io_req_ptr_t;
  next: disk_$io_req_ptr_t;
  run: disk_$io_req_ptr_t;
  vol_idx: integer;
  waited: disk_$vol_set_t;
  issued: disk_$vol_set_t;
  bit: disk_$vol_set_t;
  v: integer;
  queued: boolean;
  r: disk_$io_req_ptr_t;
  i: integer;
begin
  for i := 1 to 10 do
    map[i].head := nil;
  waited := [];
  issued := [];
  status.all := status_$ok;
  disk_bptbl[proc1_$current].io_pending := true;

  { the runs }
  cur := req_list;
  run := cur;
  vol_idx := cur^.owner_op.all;
  while cur <> nil do begin
    next := cur^.next;
    if (next = nil) or else (next^.owner_op.all <> vol_idx) then begin
      cur^.next := nil;
      if ((disk_$dvtbl[vol_idx].mount_state <> 3) and all_mounted) or else
         ((not all_mounted) and then
          ((disk_$dvtbl[vol_idx].mount_state <> 2) or else
           (disk_$dvtbl[vol_idx].mount_proc <> proc1_$current))) then
        disk_$set_chain_status(run, status_$volume_not_properly_mounted)
      else if netlog_$ok_to_log or else
              ((disk_$dvtbl[vol_idx].dev_info^.unit_count & 16#4000) <> 0)
              or else
              ((disk_$dvtbl[vol_idx].dev_info^.unit_count & 16#800) = 0) then
        while run <> nil do begin
          run^.status.all := disk_io(disk_$io_write, vol_idx, run^.ppn,
                                     run^.daddr.daddr, run^.header);
          run := run^.next;
        end
      else if 0 in disk_$dvtbl[vol_idx].as_options then
        disk_$set_chain_status(run, status_$disk_write_protected)
      else begin
        disk_$map_request(run, vol_idx, disk_$req_op_write, map, status);
        if status.all <> status_$ok then
          return;
      end;

      run := next;
      if run <> nil then
        vol_idx := run^.owner_op.all;
    end;
    cur := next;
  end;

  io_wait := disk_bptbl[proc1_$current].io_ec.value;
  err_wait := disk_bptbl[proc1_$current].err_ec.value + 1;

  { the queued chains }
  for v := 1 to 10 do
    if map[v].head <> nil then begin
      bit := [v];
      issued := issued + bit;
      disk_$do_io(disk_$dvtbl[v], map[v].head^, map[v].tail^, queued);
      if queued then begin
        io_wait := io_wait + 1;
        waited := waited + bit;
      end;
    end;

  if waited <> [] then
    disk_$wait_io(waited, io_wait, err_wait);

  { the failed requests }
  if disk_bptbl[proc1_$current].io_pending then
    return;
  for v := 1 to 10 do
    if v in issued then begin
      r := map[v].head;
      while r <> nil do begin
        if r^.status.all <> status_$ok then
          if r^.status.all = status_$disk_write_protected then
            disk_$dvtbl[v].as_options := disk_$dvtbl[v].as_options + [0]
          else begin
            disk_$io_error(v, r^, r^.header.l);
            if (r^.status.all = status_$disk_ok_after_device_recovery) or else
               (r^.status.all = status_$disk_ok_after_retry) or else
               (r^.status.all = status_$disk_ok_after_crc_correction) then
              r^.status.all := status_$ok;
          end;
        r := r^.next;
      end;
    end;
end;
