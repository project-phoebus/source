{ AREA_$COPY - copy an area, copy-on-write, into another address space.

  Image addresses:
    sau2  0x00E0901A  AREA_$COPY
    sau9  0x3C40A80C  AREA_$COPY

  - A new area of the same sizes is made for new_asid; the result is its
    handle.  The source is marked in transition for the copy.
  - Each allocated segment outside the stack has the two ASTEs found or
    made under the AST lock (a failure crashes the system) and handed to
    AST_$COPY_AREA; a failure there deletes the copy and ends the walk.
  - With the large VM layout, under the PMAP lock, the copy's segments'
    BST entries are set to none, and each copied segment's map entry in
    the source's address space is made valid on its ASTE's page map.
  - The final clear of the in-transition mark runs without the area
    lock.

  Status stored:
    status_$ok: the area was copied
    status_$area_not_active: the handle names no active area of that
      generation
    status_$area_not_owner: the caller does not own it
    area_$internal_create's or ast_$copy_area's status: those failed
}

function area_$copy(handle: area_$handle_t; new_asid: integer;
                    pid: integer; stack_limit: linteger;
                    out status: status_$t): integer32;
label
  10;
var
  delete_status: status_$t;
  new_handle: integer32;
  dst_slot: ^area_$seg_slot_t;
  src_slot: ^area_$seg_slot_t;
  dst: area_$entry_ptr_t;
  src: area_$entry_ptr_t;
  seg_direction: integer;
  seg_counter: integer;
  byte_idx: pinteger;
  is_reversed: boolean;
  stack_low_page: pinteger;
  stack_high_page: pinteger;
  segs: pinteger;
  bitmap_bytes: pinteger;
  seg_page: pinteger;
  table_idx: pinteger;
  tbl: area_$seg_table_ptr_t;
  bit: integer;
  src_aste: ast_$aste_ptr_t;
  dst_aste: ast_$aste_ptr_t;
%if large_vm %then
  k: integer;
  smap: ^mst_smap_t;
%endif
begin
  if (handle.area_id = 0) or else (handle.area_id > area_$n_areas) then
  begin
    status.all := status_$area_not_active;
    return;
  end;
  src := addr(areas[handle.area_id]);
  if (not (area_$f_active in src^.flags)) or else
     (src^.generation <> handle.generation) then begin
    status.all := status_$area_not_active;
    return;
  end;

  if (src^.remote_uid = 0) and then (proc1_$as_id <> 0) and then
     (proc1_$as_id <> src^.owner_asid) then begin
    status.all := status_$area_not_owner;
    return;
  end;

  is_reversed := area_$f_reversed in src^.flags;
  new_handle := area_$internal_create(src^.virt_size, src^.commit_size, 0,
                                      new_asid, 1, is_reversed, status);
  if status.all <> status_$ok then
    return;

  stack_low_page := rshft(as_$stack_low, 15);
  stack_high_page := rshft(stack_limit, 15);
  area_$copy := new_handle;
  dst := addr(areas[area_$handle_t(new_handle).area_id]);

  if src^.virt_size <> 0 then begin
    segs := rshft(rshft(src^.virt_size, 10) + 31, 5);
    bitmap_bytes := rshft(segs + 7, 3);
    dst^.flags := src^.flags;
    dst^.remote_uid := src^.remote_uid;

    { the source in transition }
    ml_$lock(ml_$area_lock);
    while area_$f_in_trans in src^.flags do
      area_$wait_in_trans;
    src^.flags := src^.flags + [area_$f_in_trans];
    ml_$unlock(ml_$area_lock);

    dst^.first_bste := new_asid;
    dst^.first_seg_index := src^.first_seg_index;
%if large_vm %then

    { the copy's segments' BST entries: none }
    seg_page := dst^.first_seg_index;
    ml_$lock(ml_$pmap_lock);
    if area_$f_reversed in dst^.flags then
      for k := 1 to segs do begin
        bst[seg_page + bst_asid_base[dst^.first_bste]].asid := -1;
        seg_page := seg_page - 1;
      end
    else
      for k := 1 to segs do begin
        bst[seg_page + bst_asid_base[dst^.first_bste]].asid := -1;
        seg_page := seg_page + 1;
      end;
    ml_$unlock(ml_$pmap_lock);

%endif
    seg_counter := 0;
    seg_page := src^.first_seg_index;
    if is_reversed then
      seg_direction := -1
    else
      seg_direction := 1;

    { each slot cell }
    for byte_idx := 0 to bitmap_bytes - 1 do begin
      if byte_idx < 2 then begin
        src_slot := addr(src^.seg_bitmap[byte_idx]);
        dst_slot := addr(dst^.seg_bitmap[byte_idx]);
      end
      else begin
        { the source's overflow table }
        table_idx := rshft(byte_idx, 8);
        tbl := area_$seg_table_list[src^.owner_asid];
        while tbl <> nil do begin
          if (tbl^.area_id = handle.area_id) and then
             (tbl^.table_index = table_idx) then
            exit;
          tbl := tbl^.next;
        end;
        if tbl = nil then
          crash_system(status_$area_internal_error);
        src_slot := addr(area_$seg_cells_ptr_t(tbl^.bitmap)^[
                           (byte_idx - 2) mod 256]);

        { the copy's }
        tbl := area_$seg_table_list[dst^.owner_asid];
        while tbl <> nil do begin
          if (tbl^.area_id = area_$handle_t(new_handle).area_id) and then
             (tbl^.table_index = table_idx) then
            exit;
          tbl := tbl^.next;
        end;
        if tbl = nil then
          crash_system(status_$area_internal_error);
        dst_slot := addr(area_$seg_cells_ptr_t(tbl^.bitmap)^[
                           (byte_idx - 2) mod 256]);
      end;

      { the cell's eight segments }
      for bit := 0 to 7 do begin
        if (bit in src_slot^.bits) and then
           ((seg_page < stack_low_page) or else
            (seg_page >= stack_high_page)) then begin
          ml_$lock(ml_$ast_lock);
          src_aste := area_$get_aste(handle.area_id, src_slot^, seg_counter,
                                     false, true, status);
          if status.all <> status_$ok then
            crash_system(status_$area_internal_error);
          dst_aste := area_$get_aste(area_$handle_t(new_handle).area_id,
                                     dst_slot^, seg_counter, false, true,
                                     status);
          if status.all <> status_$ok then
            crash_system(status_$area_internal_error);
          ml_$unlock(ml_$ast_lock);

%if large_vm %then
          { the source's map entry, onto its ASTE's page map }
          ml_$lock(ml_$pmap_lock);
          smap := addr(smaps[smap_asid_base[src^.owner_asid] + seg_page]);
          smap^.table := (smap^.table & 15) + src_aste^.pmap_pa;
          smap^.lim.limit := 31;
          smap^.ctl.dt := mst_smap_valid;
          smap^.flags := smap^.flags - [9];
          smap^.flags := smap^.flags + [10..15];
          ml_$unlock(ml_$pmap_lock);

%endif
          ast_$copy_area(handle.area_id, pid, src_aste^, dst_aste^,
                         seg_counter, lshft(seg_page, 15), status);
          src_aste^.wire_count := src_aste^.wire_count - 1;
          dst_aste^.wire_count := dst_aste^.wire_count - 1;
          if status.all <> status_$ok then begin
            area_$internal_delete(dst^, dst^.area_id, delete_status, true);
            goto 10;
          end;
        end;

        seg_counter := seg_counter + 1;
        seg_page := seg_page + seg_direction;
      end;
    end;
  end;

10:
  src^.flags := src^.flags - [area_$f_in_trans];
  ec_$advance(area_$in_trans_ec);
end;
