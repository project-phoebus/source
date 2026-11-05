{ AREA_$DEACTIVATE_ASTE - write back and unchain the ASTE of an area segment.

  Image addresses:
    sau2  0x00E09EF4  AREA_$DEACTIVATE_ASTE
    sau4  0x0F80A728  AREA_$DEACTIVATE_ASTE
    sau6  0x7800A87C  AREA_$DEACTIVATE_ASTE
    sau7  0x3C40B1B4  AREA_$DEACTIVATE_ASTE
    sau9  0x3C40B9B4  AREA_$DEACTIVATE_ASTE

  - Under the AST lock the segment's slot cell is found (in the entry,
    or an overflow table: none crashes the system).
  - A dirty ASTE's segment map goes into the group's page-map block: a
    local area's through DBUF (a new block from BAT_$ALLOCATE), a remote
    one's cached.
  - The ASTE is then clean and leaves the group's chain (not found
    crashes the system).
  - With the large VM layout, after the AST lock is released, every
    segment map entry on the BST thread of the area's segment is made
    invalid, under the PMAP lock.
  - DBUF_$SET_BUFF's status is not tested; the block goes back unmasked;
    the unlink loop starts past the head; two exits return without the
    AST lock.

  Status stored:
    status_$ok: the ASTE was written back and unchained
    dbuf_$set_buff's status: a local area's block was written back
    status_$ast_segment_not_deactivatable: the group's cell is busy
    bat_$allocate's, dbuf_$get_block's or area_$rpmap_get's status:
      those failed
}

procedure area_$deactivate_aste(var aste: ast_$aste_t;
                                out status_ret: status_$t);
label
  99;
var
  daddr: linteger;
  row: ast_$pmap_lrow_ptr_t;
  dbuf_flags: integer;
  entry: area_$entry_ptr_t;
  slot: ^area_$seg_slot_t;
  tbl: area_$seg_table_ptr_t;
  n: pinteger;
  group: 0..7;
  own_in_trans: boolean;
  page: ast_$pmap_lblock_ptr_t;
  a: ast_$aste_ptr_t;
  prev: ast_$aste_ptr_t;
  k: integer;
%if large_vm %then
  seg: pinteger;
  link: mst_$pmap_link_t;
%endif
begin
  status_ret.all := status_$ok;
  entry := area_$entry_ptr_t(aste.aote);
  ml_$lock(ml_$ast_lock);

  { the segment's slot cell }
  n := aste.segment div 8;
  if n < 2 then
    slot := addr(entry^.seg_bitmap[n])
  else begin
    tbl := area_$seg_table_list[entry^.owner_asid];
    while tbl <> nil do begin
      if (tbl^.area_id = entry^.area_id) and then
         (tbl^.table_index = (n - 2) div 256) then
        exit;
      tbl := tbl^.next;
    end;
    if tbl = nil then
      crash_system(status_$area_internal_error);
    slot := addr(area_$seg_cells_ptr_t(tbl^.bitmap)^[(n - 2) mod 256]);
  end;

  { write a dirty map back }
  if 13 in aste.flags then begin
    row := addr(ast_pmaps[aste.seg_index]);
    group := aste.segment & 7;
    daddr := aste.fm_block.block;
    if entry^.remote_volx = 0 then begin
      own_in_trans := false;
      if daddr = 0 then begin
        { a block for the group }
        if area_$slot_in_trans in slot^.state then begin
          ml_$unlock(ml_$ast_lock);
          status_ret.all := status_$ast_segment_not_deactivatable;
          return;
        end;
        slot^.state := slot^.state + [area_$slot_in_trans];
        own_in_trans := true;
        ml_$unlock(ml_$ast_lock);
        for k := 0 to 31 do
          if ast_$pmap_drow_ptr_t(row)^[k].daddr <> 0 then begin
            daddr := ast_$pmap_drow_ptr_t(row)^[k].daddr;
            exit;
          end;
        bat_$allocate(entry^.volx, daddr, 1, 0, daddr, status_ret);
        if status_ret.all <> status_$ok then begin
          ml_$lock(ml_$ast_lock);
          slot^.state := slot^.state - [area_$slot_in_trans];
          ec_$advance(area_$pite_in_trans_ec);
          goto 99;
        end;
        a := addr(ast[slot^.aste_index]);
        while a <> nil do begin
          a^.fm_block.block := daddr;
          a := a^.next;
        end;
        dbuf_flags := 16#10;
      end
      else begin
        dbuf_flags := 0;
        ml_$unlock(ml_$ast_lock);
      end;

      { the map into the block's row }
      page := dbuf_$get_block(entry^.volx, daddr, anon_$uid, daddr, 1,
                              dbuf_flags, status_ret);
      if status_ret.all <> status_$ok then begin
        if not own_in_trans then
          return;
        ml_$lock(ml_$ast_lock);
        slot^.state := slot^.state - [area_$slot_in_trans];
        ec_$advance(area_$pite_in_trans_ec);
        goto 99;
      end;
      for k := 0 to 31 do
        page^[group][k] := row^[k];
      dbuf_$set_buff(page, 9, status_ret);
      ml_$lock(ml_$ast_lock);
      if own_in_trans then begin
        slot^.state := slot^.state - [area_$slot_in_trans];
        ec_$advance(area_$pite_in_trans_ec);
      end;
    end
    else begin
      { the remote area's cached page }
      page := area_$rpmap_get(entry^, aste.segment, true, daddr = 0,
                              status_ret);
      if status_ret.all <> status_$ok then
        goto 99;
      if daddr = 0 then begin
        a := addr(ast[slot^.aste_index]);
        while a <> nil do begin
          a^.fm_block.block := 1;
          a := a^.next;
        end;
      end;
      for k := 0 to 31 do
        page^[group][k] := row^[k];
    end;
    aste.flags := aste.flags - [13];
  end;

  { leave the group's chain }
  if slot^.aste_index = aste.seg_index then begin
    if aste.next <> nil then
      slot^.aste_index := aste.next^.seg_index
    else begin
      slot^.state := slot^.state - [area_$slot_has_aste];
      slot^.daddr := aste.fm_block.block;
    end;
  end
  else begin
    prev := addr(ast[slot^.aste_index]);
    while prev^.next <> addr(aste) do begin
      prev := prev^.next;
      if prev = nil then
        crash_system(status_$area_internal_error);
    end;
    prev^.next := aste.next;
  end;

%if large_vm %then
  ml_$unlock(ml_$ast_lock);

  { the map entries of the segment's thread: invalid }
  with area_$entry_ptr_t(aste.aote)^ do
    if first_bste <> -1 then begin
      if area_$f_reversed in flags then
        seg := first_seg_index - aste.segment
      else
        seg := first_seg_index + aste.segment;
      link.asid := first_bste;
      link.seg := seg;
      ml_$lock(ml_$pmap_lock);
      while link.asid <> -1 do begin
%if region_mmu %then
        smaps[smap_asid_base[link.asid] + link.seg].e.valid := false;
%else
        smaps[smap_asid_base[link.asid] + link.seg].ctl.dt :=
          mst_smap_invalid;
%endif
        link := bst[bst_asid_base[link.asid] + link.seg];
      end;
      ml_$unlock(ml_$pmap_lock);
    end;
  return;

%endif
99:
  ml_$unlock(ml_$ast_lock);
end;
