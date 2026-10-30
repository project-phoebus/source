{ DISK_$SORT - order a request chain for the drive.

  Image addresses:
    sau2  0x00E3C3E4  DISK_$SORT
    sau2  0x00E3C370  disk_$sort_swap_entries (nested)

  - Pass 1 exchange-sorts the chain by absolute address (unsigned) or
    block number.  The new head goes back to the caller.
  - Pass 2, unless the volume's interleave (bat_step) is 1, moves a
    request too close after the one before it on the same cylinder and
    head behind the first that is bat_step sectors or more away.

  Status stored: none.
}

procedure disk_$sort(in vol: disk_$volume_t;
                     in out queue: disk_$io_req_ptr_t);
var
  prev_nxt: disk_$io_req_ptr_t;
  prev_cur: disk_$io_req_ptr_t;
  cur: disk_$io_req_ptr_t;
  nxt: disk_$io_req_ptr_t;
  head: disk_$io_req_ptr_t;

  { disk_$sort_swap_entries - exchange cur and nxt in the chain.

    - Nested in DISK_$SORT; afterwards cur and nxt name the swapped
      requests.

    Status stored: none.
  }
  procedure disk_$sort_swap_entries;
  var
    t: disk_$io_req_ptr_t;
  begin
    if cur = head then
      head := nxt;

    t := cur^.next;
    prev_cur^.next := nxt;
    cur^.next := nxt^.next;
    if t = nxt then
      nxt^.next := cur
    else begin
      nxt^.next := t;
      prev_nxt^.next := cur;
    end;

    t := cur;
    if prev_cur = cur then
      prev_cur := nxt;
    cur := nxt;
    nxt := t;
  end;

begin
  head := queue;

  { pass 1, the exchange sort }
  if (vol.dev_info^.unit_count & 16#200) = 0 then begin
    cur := head;
    prev_cur := cur;
    while cur <> nil do begin
      prev_nxt := cur;
      nxt := cur^.next;
      while nxt <> nil do begin
        if nxt^.header.abs_daddr < cur^.header.abs_daddr then
          disk_$sort_swap_entries;
        prev_nxt := nxt;
        nxt := nxt^.next;
      end;
      prev_cur := cur;
      cur := cur^.next;
    end;
  end
  else begin
    cur := head;
    prev_cur := cur;
    while cur <> nil do begin
      prev_nxt := cur;
      nxt := cur^.next;
      while nxt <> nil do begin
        if nxt^.daddr.daddr < cur^.daddr.daddr then
          disk_$sort_swap_entries;
        prev_nxt := nxt;
        nxt := nxt^.next;
      end;
      prev_cur := cur;
      cur := cur^.next;
    end;
  end;

  { pass 2, the interleave }
  if vol.bat_step <> 1 then begin
    prev_cur := head;
    cur := head^.next;
    while cur <> nil do begin
      if (prev_cur^.daddr.cyl = cur^.daddr.cyl) and then
         (prev_cur^.daddr.head = cur^.daddr.head) and then
         (cur^.daddr.sector - prev_cur^.daddr.sector < vol.bat_step) then begin
        prev_nxt := cur;
        nxt := cur^.next;
        while nxt <> nil do begin
          if (prev_cur^.daddr.cyl <> nxt^.daddr.cyl) or else
             (prev_cur^.daddr.head <> nxt^.daddr.head) then
            exit;
          if nxt^.daddr.sector - prev_cur^.daddr.sector >= vol.bat_step then
            begin
            disk_$sort_swap_entries;
            exit;
          end;
          prev_nxt := nxt;
          nxt := nxt^.next;
        end;
      end;
      prev_cur := cur;
      cur := cur^.next;
    end;
  end;

  queue := head;
end;
