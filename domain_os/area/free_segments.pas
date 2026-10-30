{ area_$free_segments - release the pages start_page..end_page of an
  area, and with clear set forget its segments.

  Image addresses:
    sau2  0x00E082A8  area_$free_slot_segments (nested)
    sau2  0x00E085A6  area_$free_segments (module-local)
    sau9  0x3C409944  area_$free_slot_segments (nested)
    sau9  0x3C409C3A  area_$free_segments (module-local)

  - Each slot cell the pages' segments lie in goes to the nested
    area_$free_slot_segments: cells 0 and 1 in the area entry, the
    others in overflow tables of 256 cells (a missing one crashes).
  - With clear set, a table entered at its cell 0 is freed, unless it is
    the first and the release starts inside it.  Queued disk blocks are
    freed at the end (a failure crashes the system).

  Status stored:
    status_$ok: always (a failure crashes the system)
}

procedure area_$free_segments(area_id: integer; start_page: linteger;
                              end_page: linteger; clear: boolean;
                              out status: status_$t); internal;
label
  10;
var
  bat_list: array[1..31] of linteger;
  prev: area_$seg_table_ptr_t;
  entry: area_$entry_ptr_t;
  bat_count: pinteger;
  last_tbl: integer;
  last_cell: integer;
  last_seg: pinteger;
  first_seg: pinteger;
  k: integer;
  first_cell_n: integer32;
  last_cell_n: integer32;
  first_n: integer;
  last_n: integer;
  hi: integer;
  n: integer;                             { then D2 }
  first_tbl: integer;
  t: integer;
  first_cell: integer;
  tbl: area_$seg_table_ptr_t;

  { area_$free_slot_segments - release the segments of one slot cell
    that lie in first_seg..last_seg.

    Image addresses:
      sau2  0x00E082A8  area_$free_slot_segments (nested)
      sau9  0x3C409944  area_$free_slot_segments (nested)

    - Under the AST lock the cell is held in transition while each
      allocated segment in range has its pages freed (AST_$FREE_PAGES,
      the lock released); with clear set from page 0 its bit is dropped
      and its ASTE freed.
    - With clear set and no bit left, the cell's page-map block is freed
      (a local area's) or forgotten in the RPMAP cache (a remote one's).
    - Any failure but "none active" crashes the system.

    Status stored (in the parent's status):
      status_$ok: the segments were released
  }

  procedure area_$free_slot_segments(var slot: area_$seg_slot_t;
                                     n: pinteger);
  var
    is_local: boolean;
    last_page: integer;
    seg: pinteger;
    seg_hi: integer;
    s: pinteger;
    bit: pinteger;
    first_page: integer;
    aste: ast_$aste_ptr_t;
    link: ast_$aste_ptr_t;
  begin
    { the segments in range }
    seg := n * 8;
    if seg <= first_seg then
      seg := first_seg;
    seg_hi := min(last_seg, n * 8 + 7);
    is_local := entry^.remote_volx = 0;

    ml_$lock(ml_$ast_lock);
    while area_$slot_in_trans in slot.state do
      area_$wait_pite_in_trans;
    slot.state := slot.state + [area_$slot_in_trans];

    { the allocated segments }
    if slot.bits <> [] then
      for s := seg to seg_hi do begin
        bit := s & 7;
        if bit in slot.bits then begin
          if s = first_seg then
            first_page := start_page & 16#1F
          else
            first_page := 0;
          if s = last_seg then
            last_page := end_page & 16#1F
          else
            last_page := 16#1F;
          aste := area_$get_aste(area_id, slot, s, true, is_local, status);
          if status.all = status_$ast_segment_not_deactivatable then begin
            status.all := status_$ok;
            if clear and then (first_page = 0) then
              slot.bits := slot.bits - [bit];
          end
          else begin
            if status.all <> status_$ok then
              crash_system(status_$area_internal_error);
            ml_$unlock(ml_$ast_lock);
            ast_$free_pages(aste^, first_page, last_page, entry^.volx);
            ml_$lock(ml_$ast_lock);
            if clear and then (first_page = 0) then begin
              slot.bits := slot.bits - [bit];
              link := addr(ast[slot.aste_index]);
              if link = aste then begin
                if aste^.next = nil then begin
                  slot.state := slot.state - [area_$slot_has_aste];
                  slot.daddr := aste^.fm_block.block;
                end
                else
                  slot.aste_index := aste^.next^.seg_index;
              end
              else begin
                while link^.next <> aste do begin
                  link := link^.next;
                  if link = nil then
                    crash_system(status_$area_internal_error);
                end;
                link^.next := aste^.next;
              end;
              ast_$free_aste(aste^);
            end
            else
              aste^.wire_count := aste^.wire_count - 1;
          end;
        end;
      end;

    { the group's page-map block }
    if clear and then (slot.bits = []) and then (slot.daddr <> 0) then
    begin
      if entry^.remote_volx = 0 then begin
        bat_count := bat_count + 1;
        bat_list[bat_count] := slot.daddr;
        dbuf_$invalidate(bat_list[bat_count], entry^.volx);
        if bat_count >= 31 then begin
          ml_$unlock(ml_$ast_lock);
          bat_$free(bat_list, bat_count, entry^.volx, 0, status);
          ml_$lock(ml_$ast_lock);
          if status.all <> status_$ok then
            crash_system(status);
          bat_count := 0;
        end;
      end
      else
        for k := 1 to 3 do
          with area_$rpmap_slots[k] do
            if (volx = entry^.remote_volx) and then (n = group) then begin
              seq := 0;
              volx := 0;
              dirty := false;
              exit;
            end;
      slot.daddr := 0;
    end;

    slot.state := slot.state - [area_$slot_in_trans];
    ml_$unlock(ml_$ast_lock);
  end;

begin
  status.all := status_$ok;
  bat_count := 0;
  entry := addr(areas[area_id]);
  first_seg := rshft(start_page, 5);
  last_seg := rshft(end_page, 5);
  first_n := rshft(first_seg, 3);
  last_n := rshft(last_seg, 3);

  { the entry's two cells }
  if first_n < 2 then begin
    hi := 1;
    if hi > last_n then
      hi := last_n;
    for n := first_n to hi do
      area_$free_slot_segments(entry^.seg_bitmap[n], n);
  end;

  { the overflow tables }
  if last_n < 2 then
    goto 10;
  if first_n < 2 then
    first_n := 2;
  n := first_n;
  first_cell_n := first_n - 2;
  last_cell_n := last_n - 2;
  first_tbl := rshft(first_cell_n, 8);
  last_tbl := rshft(last_cell_n, 8);

  for t := first_tbl to last_tbl do begin
    { the table's cells in range }
    first_cell := 0;
    if t = first_tbl then
      first_cell := first_cell_n mod 256;
    last_cell := 16#FF;
    if t = last_tbl then
      last_cell := last_cell_n mod 256;

    { the table on the owner's list }
    tbl := area_$seg_table_list[entry^.owner_asid];
    prev := nil;
    while tbl <> nil do begin
      if (tbl^.area_id = area_id) and then (tbl^.table_index = t) then
        exit;
      prev := tbl;
      tbl := tbl^.next;
    end;
    if tbl = nil then
      crash_system(status_$area_internal_error);

    for k := first_cell to last_cell do begin
      area_$free_slot_segments(area_$seg_cells_ptr_t(tbl^.bitmap)^[k], n);
      n := n + 1;
    end;

    { a table cleared from its start }
    if (first_cell = 0) and then clear then
      if (t > first_tbl) or else (start_page <= 16#200) or else
         ((start_page - 16#200) mod 256 = 0) then
        area_$free_seg_table(tbl, prev, entry^.owner_asid);
  end;

  { the blocks still queued }
10:
  if bat_count <> 0 then begin
    bat_$free(bat_list, bat_count, entry^.volx, 0, status);
    if status.all <> status_$ok then
      crash_system(status);
  end;
end;
