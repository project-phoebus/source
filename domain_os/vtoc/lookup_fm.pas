{ VTOCE_$LOOKUP_FM - find (or make) the file-map block of a segment.

  Image addresses:
    sau2  0x00E39A04  VTOCE_$LOOKUP_FM
    sau2  0x00E397D0  vtoc_$fm_traverse (nested)

  - Under ml_$vtoc_lock: segment 0 is the VTOCE's own map; otherwise the
    segment picks one of three indirect trees (1..8, 9..2056, above).
  - The nested walk descends to the 32-entry file map, allocating when
    allowed.
  - "Mounted read-only" from the walk becomes success at (1, 15).

  Status stored:
    dbuf_$set_buff's status: the walk succeeded
    status_$ok: the walk said "mounted read-only"
    status_$vtoc_not_mounted: the volume is not mounted
    dbuf_$get_block's status: the VTOCE block could not be read
    the walk's status: it failed
}

procedure vtoce_$lookup_fm(in vtoce_loc: vtoc_$lookup_req_t;
                           segment: pinteger; allocate: boolean;
                           out fm_loc: fm_$block_addr_t;
                           out alloc_count: integer32;
                           out status: status_$t);
label
  90;
var
  local_status: status_$t;
  offset: integer32;
  block: linteger;
  vol_idx: integer;
  dirty: integer;
  divisor: pinteger;
  idx: pinteger;
  entry: pinteger;
  buf: fm_$buffer_ptr_t;
  roots: vtoc_$fm_roots_ptr_t;

  { vtoc_$fm_traverse - one level of a file-map tree.

    - A missing block is allocated when allowed (near the hint, or a
      file-map block), cleared and entered in slot; above the last level
      the child's block is found, a hint made for a missing one, and the
      walk descends.  The result is the buffers' dirt.
    - Nested in VTOCE_$LOOKUP_FM, whose locals it reaches.
    - A new block is used without testing DBUF_$GET_BLOCK's status.

    Status stored:
      status_$vtoc_no_file_map: a missing block, no allocation allowed
      status_$file_volume_has_been_mounted_read_only: the volume is
        read-only
      the BAT or DBUF routine's status: that step failed
  }

  function vtoc_$fm_traverse(var slot: integer32; level: integer;
                             hint: linteger): integer;
  var
    buf: fm_$buffer_ptr_t;
    dirty: integer;
    j: pinteger;
    k: pinteger;                          { the hint's search }
    i: integer;                           { the fill }
  begin
    dirty := bat_buf_clean;
    vtoc_$fm_traverse := bat_buf_clean;

    { the level's block }
    if slot <> 0 then begin
      block := slot;
      buf := nil;
    end
    else begin
      if not allocate then begin
        status.all := status_$vtoc_no_file_map;
        return;
      end;
      if vtoc_$cach_wp_flag[vol_idx] then begin
        status.all := status_$file_volume_has_been_mounted_read_only;
        return;
      end;
      if vtoc_$format[vol_idx] then begin
        if hint = 0 then
          block := bat_$alloc_fm(vol_idx, status)
        else
          bat_$allocate(vol_idx, hint, 1, 0, block, status);
      end
      else begin
        if vtoce_loc.block_hint.block_num = block then
          block := 0;
        bat_$allocate(vol_idx, block, 1, 0, block, status);
      end;
      if status.all <> status_$ok then
        return;
      alloc_count := alloc_count + 1;
      buf := dbuf_$get_block(vol_idx, block, vtoce_loc.uid, offset, level,
                             dbuf_get_no_read, status);
      for i := 0 to 255 do
        buf^.longs[i] := 0;
      slot := block;
      dirty := bat_buf_writeback;
    end;

    { the level's result; the next level }
    vtoc_$fm_traverse := dirty & (-3);
    if level > 1 then begin
      if buf = nil then begin
        buf := dbuf_$get_block(vol_idx, block, vtoce_loc.uid, offset,
                               level, 0, status);
        if status.all <> status_$ok then
          return;
      end;
      j := idx div divisor;
      idx := idx & (divisor - 1);
      offset := offset + j * divisor * 32;
      divisor := 8;
      if buf^.longs[j] = 0 then begin
        if j = 0 then
          hint := block
        else if (level > 2) or else ((j & 7) = 0) then
          hint := 0
        else
          for k := j - 1 downto j & (-8) do begin
            hint := buf^.longs[k];
            if hint <> 0 then
              exit;
          end;
      end;
      dirty := dirty ! vtoc_$fm_traverse(buf^.longs[j], level - 1, hint);
      if status.all <> status_$ok then begin
        dbuf_$set_buff(buf, dirty, local_status);
        return;
      end;
    end;

    if buf <> nil then
      dbuf_$set_buff(buf, dirty, status);
  end;

begin
  block := vtoce_loc.block_hint.block_num;
  entry := vtoce_loc.block_hint.entry_idx;
  vol_idx := vtoce_loc.tail.vol_idx;

  ml_$lock(ml_$vtoc_lock);
  if not vtoc_$mounted[vol_idx] then
    status.all := status_$vtoc_not_mounted
  else
    buf := dbuf_$get_block(vol_idx, block, vtoc_$uid, block, 0, 0, status);
  if status.all <> status_$ok then
    goto 90;

  { the segment's tree }
  dirty := bat_buf_clean;
  alloc_count := 0;
  if segment = 0 then
    idx := entry
  else begin
    if vtoc_$format[vol_idx] then
      roots := addr(buf^.new_vtoc.entries[entry].indirect)
    else
      roots := addr(buf^.old_vtoc.entries[entry].indirect);
    if segment < 9 then begin
      idx := segment - 1;
      offset := 16#20;
      dirty := vtoc_$fm_traverse(roots^[1], 1, 0);
    end
    else if segment < 16#809 then begin
      idx := segment - 9;
      offset := 16#120;
      divisor := 8;
      dirty := vtoc_$fm_traverse(roots^[2], 2, 0);
    end
    else begin
      idx := segment - 16#809;
      offset := 16#10120;
      divisor := 16#800;
      dirty := vtoc_$fm_traverse(roots^[3], 3, 0);
    end;
  end;

  dbuf_$set_buff(buf, dirty, local_status);
  if status.all = status_$ok then
    status := local_status
  else if status.all = status_$file_volume_has_been_mounted_read_only then
    begin
    block := 1;
    idx := 15;
    status.all := status_$ok;
  end;
  fm_loc.block_num := block;
  fm_loc.entry_idx := idx;

90:
  ml_$unlock(ml_$vtoc_lock);
end;
