{ area_$get_aste - get, activating it if need be, the ASTE of one area segment.

  Image addresses:
    sau2  0x00E09A6A  area_$get_aste (module-local)
    sau4  0x0F80A286  area_$get_aste (module-local)
    sau6  0x7800A400  area_$get_aste (module-local)
    sau7  0x3C40AD38  area_$get_aste (module-local)
    sau9  0x3C40B538  area_$get_aste (module-local)

  Assume we're called with the AST lock held.

  - The slot is the cell of a group of eight segments.  Unless the
    caller holds the cell's transition, it is waited out; an active ASTE
    of the segment is wired once more, locked and returned.
  - Otherwise, with create, a fresh ASTE gets the segment's map from the
    group's page-map block (through DBUF or area_$rpmap_get), or a
    cleared one for a new segment, and is chained onto the group.
  - The failure exits do not assign the result.

  Status stored:
    status_$ok: the ASTE was found or made
    status_$ast_segment_not_deactivatable: not found, and not to be
      created
    dbuf_$get_block's, dbuf_$set_buff's or area_$rpmap_get's status:
      the segment's map could not be read
}

function area_$get_aste(area_id: pinteger; var slot: area_$seg_slot_t;
                        seg_idx: integer; in_trans_held: boolean;
                        create: boolean;
                        out status: status_$t): ast_$aste_ptr_t;
label
  10, 30;
var
  daddr: linteger;
  row: ast_$pmap_lrow_ptr_t;
  group: 0..7;
  a: ast_$aste_ptr_t;
  entry: area_$entry_ptr_t;
  aste: ast_$aste_ptr_t;
  blk: ast_$pmap_lblock_ptr_t;
  k: integer;
begin
  status.all := status_$ok;
  group := seg_idx & 7;
  if not in_trans_held then
    while area_$slot_in_trans in slot.state do
      area_$wait_pite_in_trans;

  { the group's chain }
10:
  if area_$slot_has_aste in slot.state then begin
    a := addr(ast[slot.aste_index]);
    while a <> nil do begin
      if a^.segment = seg_idx then begin
        if 15 in a^.flags then begin
          ast_$wait_for_ast_intrans;
          goto 10;
        end;
        a^.wire_count := a^.wire_count + 1;
        a^.flags := a^.flags + [14];
        area_$get_aste := a;
        return;
      end;
      a := a^.next;
    end;
  end;

  if not create then begin
    status.all := status_$ast_segment_not_deactivatable;
    return;
  end;

  { a new ASTE }
  slot.state := slot.state + [area_$slot_in_trans];
  entry := addr(areas[area_id]);
  aste := ast_$allocate_aste;
  aste^.aote := ast_$aote_ptr_t(entry);
%if large_vm %then
  { no MST entry maps its page map yet }
  aste^.pmap_link.asid := -1;
%endif
  ast_$aste_area_cnt := ast_$aste_area_cnt + 1;
  aste^.segment := seg_idx;
  aste^.page_count := chr(0);
  aste^.wire_count := 1;
  aste^.flag_bits.in_trans := false;
  aste^.flag_bits.locked := true;
  aste^.flag_bits.dirty := false;
  aste^.flag_bits.area := true;
  aste^.flag_bits.remote := entry^.remote_volx <> 0;

  row := addr(ast_pmaps[aste^.seg_index]);

  if group in slot.bits then begin
    if entry^.remote_volx = 0 then begin
      { from the page-map block, through DBUF }
      if area_$slot_has_aste in slot.state then
        daddr := ast[slot.aste_index].fm_block.block
      else
        daddr := slot.daddr;
      ml_$unlock(ml_$ast_lock);
      blk := dbuf_$get_block(entry^.volx, daddr, anon_$uid, daddr, 1, 0,
                             status);
      ml_$lock(ml_$ast_lock);
      if status.all <> status_$ok then begin
        ast_$free_aste(aste^);
        goto 30;
      end;
      for k := 0 to 31 do
        row^[k] := blk^[group][k];
      dbuf_$set_buff(blk, 8, status);
    end
    else begin
      { from the remote area's cached page }
      blk := area_$rpmap_get(entry^, seg_idx, false, false, status);
      if status.all <> status_$ok then begin
        ast_$free_aste(aste^);
        goto 30;
      end;
      for k := 0 to 31 do
        row^[k] := blk^[group][k];
    end;
  end
  else begin
    { a new segment }
    for k := 0 to 31 do
      row^[k] := 0;
    slot.bits := slot.bits + [group];
    aste^.flags := aste^.flags + [13];
  end;

  { chain it }
  if area_$slot_has_aste in slot.state then begin
    aste^.next := addr(ast[slot.aste_index]);
    aste^.fm_block := ast[slot.aste_index].fm_block;
  end
  else begin
    aste^.next := nil;
    aste^.fm_block.block := slot.daddr;
    slot.state := slot.state + [area_$slot_has_aste];
  end;
  aste^.fm_block.group := group;
  slot.aste_index := aste^.seg_index;
  area_$get_aste := aste;

30:
  if not in_trans_held then begin
    slot.state := slot.state - [area_$slot_in_trans];
    ec_$advance(area_$pite_in_trans_ec);
  end;
end;
