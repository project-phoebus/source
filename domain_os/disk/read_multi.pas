{ DISK_$READ_MULTI - read a chain of queue blocks from one volume.

  Image addresses:
    sau2  0x00E3CFCC  DISK_$READ_MULTI

  - With NETLOG on, a checksumming device or one without queued reads,
    the blocks are read one at a time through DISK_IO.
  - Otherwise the chain is mapped and each volume's part goes to its
    driver; the queued ones are waited for.
  - The blocks are then checked in order (the first block's header the
    pattern); a failed one goes to disk_$io_error and is checked again
    or ends the routine.

  Status stored:
    the first block's status: the blocks were read, or not
    status_$invalid_volume_index: an invalid index
    status_$volume_not_properly_mounted: not mounted as the caller says
    disk_$map_request's status: the chain could not be mapped
}

{ TODO(pascal) the failed block's search tests r twice before its loop

  The image tests the pointer once before the loop and again at the
  `while' test at the bottom.  The Pascal writes `if r <> nil then while
  r <> nil do', which gives that code; no other site of the shape is in
  the SAU2 image, and DISK_$WRITE_MULTI's like loop has the plain
  `while' entry.  The source construct is not identified. }

procedure disk_$read_multi(vol_idx: pinteger; mounted: boolean;
                           check_hdr: boolean; qblk_head: disk_$io_req_ptr_t;
                           qblk_tail: disk_$io_req_ptr_t;
                           out pages_read: integer; out status: status_$t);
label
  10, 20;
var
  hdr: disk_$block_hdr_t;
  map: disk_$vol_map_t;
  err_wait: integer32;
  io_wait: integer32;
  req: disk_$io_req_ptr_t;
  r: disk_$io_req_ptr_t;
  waited: disk_$vol_set_t;
  verify: boolean;
  op: integer;
  result: boolean;
  v: integer;
  i: integer;
  queued: boolean;
begin
  pages_read := 0;
  status.all := status_$ok;
  waited := [];
  if vol_idx > 10 then begin
    status.all := status_$invalid_volume_index;
    return;
  end;

  for i := 1 to 10 do
    map[i].head := nil;

  with disk_$dvtbl[vol_idx] do begin
    if mounted then begin
      if mount_state <> 3 then begin
        status.all := status_$volume_not_properly_mounted;
        return;
      end;
    end
    else if (mount_state <> 2) and then (mount_proc <> proc1_$current) then
    begin
      status.all := status_$volume_not_properly_mounted;
      return;
    end;

    hdr := qblk_head^.header;

    if netlog_$ok_to_log or else ((dev_info^.unit_count & 16#4000) <> 0)
       or else ((dev_info^.unit_count & 16#2000) = 0) then begin
      { a block at a time }
      req := qblk_head;
      if check_hdr then
        op := disk_$io_read
      else
        op := disk_$io_read_no_check;
      while req <> nil do begin
        req^.header := hdr;
        req^.status.all := disk_io(op, vol_idx, req^.ppn, req^.daddr.daddr,
                                   req^.header);
        if req^.status.all <> status_$ok then
          goto 10;
        hdr.hint := hdr.hint + 1;
        pages_read := pages_read + 1;
        req := req^.free_next;
      end;
    end
    else begin
      { queued }
      r := qblk_head;
      while r <> nil do begin
        r^.header.hint := ~r^.header.hint;
        r := r^.free_next;
      end;
      disk_$map_request(qblk_head, vol_idx, disk_$req_op_read, map, status);
      if status.all <> status_$ok then
        return;

      io_wait := disk_bptbl[proc1_$current].io_ec.value;
      err_wait := disk_bptbl[proc1_$current].err_ec.value + 1;
      disk_bptbl[proc1_$current].io_pending := true;

      for v := 1 to 10 do
        if map[v].head <> nil then begin
          disk_$do_io(disk_$dvtbl[v], map[v].head^, map[v].tail^, queued);
          result := queued;
          mmu_$mcr_change(6);
          if result then begin
            io_wait := io_wait + 1;
            waited := waited + [v];
          end;
        end;

      if waited <> [] then
        disk_$wait_io(waited, io_wait, err_wait);

      verify := (dev_info^.unit_count & 16#8000) = 0;
      req := qblk_head;

      { the checks }
      while req <> nil do begin
20:
        if check_hdr and then verify then
          if req^.status.all = status_$ok then
            if (req^.header.hint <> hdr.hint) or else
               (req^.header.uid <> hdr.uid) then
              req^.status.all := status_$disk_block_header_error;
        if req^.status.all <> status_$ok then
          for v := 1 to 10 do begin
            r := map[v].head;
            if r <> nil then
              while r <> nil do begin
                if r = req then begin
                  disk_$io_error(v, req^, hdr.l);
                  if (req^.status.all = status_$disk_ok_after_device_recovery)
                     or else (req^.status.all = status_$disk_ok_after_retry)
                     or else
                     (req^.status.all = status_$disk_ok_after_crc_correction)
                  then begin
                    req^.status.all := status_$ok;
                    goto 20;
                  end;
                  goto 10;
                end;
                r := r^.next;
              end;
          end;
        hdr.hint := hdr.hint + 1;
        pages_read := pages_read + 1;
        req := req^.free_next;
      end;
    end;
  end;

10:
  status := qblk_head^.status;
end;
