{ area_$rpmap_get - the RPMAP page cache: find or fetch a remote page map.

  Image addresses:
    sau2  0x00E07370  area_$rpmap_get (module-local)
    sau9  0x3C4089A8  area_$rpmap_get (module-local)

  Assume we're called with the AST lock held.

  - On a diskless node the segment maps of an area's remote volume live
    with the partner, eight segments to a 1 KB page, cached in three
    slots.  A hit is stamped (and marked dirty if asked) and returned.
  - A miss takes the least recent slot: a dirty one is written back
    (NETWORK_$WRITE; a failure crashes the system), a clean one claimed
    and, unless flag, fetched (AST_$FETCH_PMAP_PAGE).
  - Waits drop the lock.
  - The fetch's status is passed by value; the page request's other
    bytes are not set.

  Status stored:
    status_$ok: always (the fetch's status is lost)
}

function area_$rpmap_get(in entry: area_$entry_t; seg_idx: pinteger;
                         dirty: boolean; flag: boolean;
                         out status: status_$t): univ_ptr; internal;
label
  10;
var
  wait_val: integer32;
  req: network_$page_request_t;
  dtm: time_$clock_t;
  dtv_low: pinteger;
  seg_group: pinteger;
  i: integer;
  victim: integer;
  best: linteger;
begin
  status.all := status_$ok;
  seg_group := rshft(seg_idx, 3);

  repeat
10:
    { a hit }
    for i := 1 to 3 do
      if (area_$rpmap_slots[i].group = seg_group) and then
         (area_$rpmap_slots[i].volx = entry.remote_volx) then begin
        if area_$rpmap_slots[i].in_trans then begin
          wait_val := area_$rpmap_in_trans_ec.value + 1;
          ml_$unlock(ml_$ast_lock);
          discard(ec_$waitn(addr(area_$rpmap_in_trans_ec), wait_val, 1));
          ml_$lock(ml_$ast_lock);
          goto 10;
        end;
        if dirty then
          area_$rpmap_slots[i].dirty := true;
        area_$rpmap_seq := area_$rpmap_seq + 1;
        area_$rpmap_slots[i].seq := area_$rpmap_seq;
        area_$rpmap_get := addr(area_$rpmap_cache[i]);
        return;
      end;

    { the least recently stamped slot }
    victim := 1;
    best := 16#0FFFFFFF;
    for i := 1 to 3 do
      if area_$rpmap_slots[i].seq < best then begin
        best := area_$rpmap_slots[i].seq;
        victim := i;
      end;

    req.uid.high := anon_$uid.high;
    req.reserved_10 := chr(1);
    req.sub_type := chr(0);

    with area_$rpmap_slots[victim] do
      if in_trans then begin
        wait_val := area_$rpmap_in_trans_ec.value + 1;
        ml_$unlock(ml_$ast_lock);
        discard(ec_$waitn(addr(area_$rpmap_in_trans_ec), wait_val, 1));
        ml_$lock(ml_$ast_lock);
      end
      else begin
        if dirty then begin
          { write the victim back }
          dirty := false;
          in_trans := true;
          ml_$unlock(ml_$ast_lock);
          req.uid.low := volx;
          req.page_num := group * 16#101;
          network_$write(area_$partner, req, area_$rpmap_page[victim],
                         area_$partner_pkt_size, 1, dtv_low, dtm, status);
          if status.all <> status_$ok then
            crash_system(status);
          ml_$lock(ml_$ast_lock);
        end
        else begin
          { claim it, and read it }
          volx := entry.remote_volx;
          group := seg_group;
          dirty := false;
          if flag then
            goto 10;
          req.uid.low := entry.remote_volx;
          req.page_num := seg_group * 16#101;
          in_trans := true;
          ml_$unlock(ml_$ast_lock);
          ast_$fetch_pmap_page(req, area_$rpmap_cache[victim],
                               area_$partner_pkt_size, status);
          ml_$lock(ml_$ast_lock);
          if status.all <> status_$ok then
            crash_system(status);
        end;

        in_trans := false;
        ec_$advance(area_$rpmap_in_trans_ec);
      end;
  until false;
end;
