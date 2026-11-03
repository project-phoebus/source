{ AST_$TRUNCATE - cut an object back to a new length, or delete it.

  Image addresses:
    sau2  0x00E05C40  AST_$TRUNCATE
    sau4  0x0F805FDE  AST_$TRUNCATE
    sau8  0x03C05ECA  AST_$TRUNCATE
    sau9  0x3C406ED6  AST_$TRUNCATE

  - Bit 0 of flags deletes (length 0), bit 1 forces.  Inhibited and
    under the AST lock the object is activated and marked busy.
  - A forced delete of an object referenced elsewhere only drops one
    reference.  The segments past the new end are deactivated, the end
    segment's later pages dropped and their blocks freed.
  - The VTOCE is truncated (or a remote object truncated at its node);
    a deleted object is deactivated, its kept ACL object deleted too.

  Status stored:
    status_$ok: the object was truncated or deleted
    status_$ast_only_local_access_allowed: an OS-only object, for a
      type-9 process
    16#3000B: a system object cannot be deleted
    status_$file_volume_has_been_mounted_read_only: a read-only volume
    status_$ast_segment_not_deactivatable: the AOTE is in use
    status_$pmap_pages_wired: a page to drop is wired
    the callees' statuses: a step failed (BAT_$FREE's with the fail bit)
}

procedure ast_$truncate(uid: uid_$t; new_size: integer32; flags: integer;
                        out result: boolean; out status: status_$t);
label
  10, 60, 70, 80, 90;
const
  ast_system_object_cannot_be_deleted = 16#0003000B;
var
  local_uid: file_$uid_view_t;
  buf: file_$attr_value_t;
  blocks: array[1..32] of linteger;
  net_node: ast_$net_info_t;
  second_uid: ast_$uid_byte_view_t;
  freed: integer32;
  inner_status: status_$t;
  local_status: status_$t;
  rounded_size: integer32;
  seg_offset: linteger;
  location: ast_$loc_word_t;
  row: ^ast_$pmap_t;
  aote: ast_$aote_ptr_t;
  aste: ast_$aste_ptr_t;
  is_delete: boolean;
  force: boolean;
  second_pass: boolean;
  end_seg: pinteger;
  nblocks: integer;
  i: integer;
  ppn: integer32;
begin
  is_delete := 0 in ast_$word_set_t(flags);
  force := 1 in ast_$word_set_t(flags);
  second_pass := false;
  result := false;

  local_status.all := status_$ok;
  if is_delete then
    new_size := 0;
  end_seg := rshft(new_size, 15);
  seg_offset := new_size & 16#7FFF;
  proc1_$inhibit_begin;

10:
  rounded_size := new_size;
  local_uid.uid := uid;
  local_uid.low_set := local_uid.low_set - [24];
  ml_$lock(ml_$ast_lock);

  aote := ast_$lookup_aote_by_uid(local_uid.uid);
  if aote = nil then begin
    location.all := 0;
    aote := ast_$force_activate_segment(local_uid.uid, location,
                                        local_status, false);
    if aote = nil then begin
      ml_$unlock(ml_$ast_lock);
      if second_pass and then
         (local_status.all = file_$object_not_found) then
        local_status.all := status_$ok;
      goto 80;
    end;
  end
  else
    aote^.flags := aote^.flags + [6];

  if ast_$aote_view_ptr_t(aote)^.attrs.sa.pv.tail.os_only and then
     not aote^.loc.remote and then
     (proc1_$type[proc1_$current] = 9) then begin
    local_status.all := status_$ast_only_local_access_allowed;
    goto 70;
  end;

  { deleting a local object }
  if is_delete and then not aote^.loc.remote then begin
    if force then begin
      if ast_$aote_view_ptr_t(aote)^.attrs.sa.refcount > 1 then begin
        ml_$unlock(ml_$ast_lock);
        buf.word_val := 1;
        proc1_$inhibit_end;
        ast_$set_attribute(local_uid.uid, 7, buf, local_status);
        goto 90;
      end;
    end
    else if ast_$aote_view_ptr_t(aote)^.attrs.sa.refcount <> 0 then
      goto 70;
    if ast_$aote_view_ptr_t(aote)^.attrs.sa.pv.tail.mode_6 then begin
      local_status.all := ast_system_object_cannot_be_deleted;
      goto 70;
    end;
    result := true;
    second_uid.uid := ast_$aote_view_ptr_t(aote)^.attrs.sa.acl_uid;
  end;

  if ast_$aote_view_ptr_t(aote)^.attrs.sa.aflags.special then begin
    local_status.all := status_$file_volume_has_been_mounted_read_only;
    goto 70;
  end;
  if ast_$aote_view_ptr_t(aote)^.ref_count <> 0 then begin
    local_status.all := status_$ast_segment_not_deactivatable;
    goto 70;
  end;

  { the ASTE list, from its head each pass }
  aote^.flags := aote^.flags + [7];
  while aote^.aste_list <> nil do begin
    aste := aote^.aste_list;
    if end_seg > aste^.segment then
      exit;
    if 15 in aste^.flags then begin
      ast_$wait_for_ast_intrans;
      next;
    end;

    { beyond the end }
    if (aste^.segment > end_seg) or else
       ((aste^.segment = end_seg) and then (seg_offset = 0)) then begin
      ast_$deactivate_segment(aste^, true, false, local_status);
      if local_status.all <> status_$ok then begin
        aote^.flags := aote^.flags - [7];
        goto 60;
      end;
      ast_$free_aste(aste^);
      next;
    end;

    { the segment holding the new end }
    row := addr(ast_pmaps[aste^.seg_index]);
    rounded_size := (end_seg + 1) * 16#8000;
    if aote^.length = new_size then
      exit;
    aste^.flags := aste^.flags + [15];
    ml_$unlock(ml_$ast_lock);
    ml_$lock(ml_$pmap_lock);

    { its pages past the new length }
    nblocks := 0;
    for i := rshft(seg_offset + 16#3FF, 10) to 31 do
      with row^[i] do begin
%if pmmu_page_maps or region_mmu %then
        while ast_$pmap_in_trans in flags do begin
          mmu_$purge;
          ast_$wait_for_page_transition;
        end;
%else
        while ast_$pmap_in_trans in flags do
          ast_$wait_for_page_transition;
%endif
        if ast_$pmap_installed in flags then begin
          ppn := vpn;
          with mmap[ppn] do begin
            if wire_count <> 0 then begin
              local_status.all := status_$pmap_pages_wired;
              exit;
            end;
            if seg_offset <> i then
              crash_system(status_$pmap_mismatch);
%if pmmu_page_maps or region_mmu %then
            flags := flags - [ast_$pmap_resident];
%else
            if ast_$pmap_resident in flags then begin
              flags := flags - [ast_$pmap_resident];
              mmu_$remove(ppn);
            end;
%endif
            flags := flags - [ast_$pmap_installed];
%if pmmu_page_maps %then
            vpn := disk_addr.all;
%else
            all := all & 16#FF800000;
            all := all ! disk_addr.all;
%endif
            mmap_$free_remove(mmap[ppn], ppn);
          end;
          aste^.page_count := pred(aste^.page_count);
        end;
%if pmmu_page_maps %then
        if vpn <> 0 then begin
          blocks[nblocks + 1] := dentry.daddr;
          nblocks := nblocks + 1;
          all := all & 16#3FF;
          aste^.flags := aste^.flags + [13];
        end;
%else
        if (all & 16#7FFFFF) <> 0 then begin
          blocks[nblocks + 1] := all & 16#3FFFFF;
          nblocks := nblocks + 1;
          all := all & 16#FF800000;
          aste^.flags := aste^.flags + [13];
        end;
%endif
      end;

%if pmmu_page_maps or region_mmu %then
    mmu_$purge;
%endif

    ml_$unlock(ml_$pmap_lock);
    ast_$update_aste(aste^, row^, true, inner_status);
    if local_status.all = status_$ok then
      local_status := inner_status;

    { a local object's blocks given back }
    if (nblocks <> 0) and then not aote^.loc.remote then begin
      ml_$lock(ml_$pmap_lock);
      aote^.unknown_24 := aote^.unknown_24 - nblocks;
      aote^.flags := aote^.flags + [5];
      ml_$unlock(ml_$pmap_lock);
      bat_$free(blocks, nblocks, aote^.vol_index, 0, inner_status);
      if local_status.all = status_$ok then begin
        if inner_status.all <> status_$ok then
          inner_status.fail := true;
        local_status := inner_status;
      end;
    end;

    ml_$lock(ml_$ast_lock);
    aste^.flags := aste^.flags - [15];
    ec_$advance(ast_$ast_in_trans_ec);
    if local_status.all <> status_$ok then begin
      aote^.flags := aote^.flags - [7];
      goto 60;
    end;
    exit;
  end;

  { the new length }
  if not is_delete and then (aote^.length <> new_size) then begin
    ml_$lock(ml_$pmap_lock);
    aote^.length := new_size;
    time_$clock(aote^.dta);
    aote^.dtm := aote^.dta;
    aote^.flags := aote^.flags + [5];
    ml_$unlock(ml_$pmap_lock);
  end;

  if not aote^.loc.remote then begin
    { a local object's VTOCE }
    ml_$unlock(ml_$ast_lock);
    vtoce_$truncate(ast_$aote_view_ptr_t(aote)^.obj_loc.vtoc, new_size,
                    rounded_size, is_delete, freed, local_status);
    ml_$lock(ml_$ast_lock);
    if local_status.all <> status_$ok then begin
      aote^.flags := aote^.flags - [7];
      goto 60;
    end;

    aote^.flags := aote^.flags - [7];
    if is_delete then begin
      ast_$process_aote(aote^, true, false, true, local_status);
      if local_status.all = status_$ok then
        ast_$release_aote(aote^);
    end
    else begin
      if freed <> 0 then begin
        ml_$lock(ml_$pmap_lock);
        aote^.unknown_24 := aote^.unknown_24 - freed;
        aote^.flags := aote^.flags + [5];
        ml_$unlock(ml_$pmap_lock);
      end;
      ec_$advance(ast_$ast_in_trans_ec);
    end;

    { the ACL's pass }
    ml_$unlock(ml_$ast_lock);
    if is_delete and then (local_status.all = status_$ok) and then
       (second_uid.b0 <> 0) then begin
      uid := second_uid.uid;
      force := true;
      second_pass := true;
      goto 10;
    end;
    goto 80;
  end
  else begin
    { a remote object }
    aote^.flags := aote^.flags - [7];
    if is_delete then begin
      ast_$process_aote(aote^, true, false, true, local_status);
      if local_status.all <> status_$ok then
        goto 60;
      ast_$release_aote(aote^);
    end
    else
      ec_$advance(ast_$ast_in_trans_ec);

    net_node.uid := aote^.obj_loc_addr;
    ml_$unlock(ml_$ast_lock);
    rem_file_$truncate(net_node.addr, local_uid.uid, new_size, is_delete,
                       buf.clock, status);

    if not is_delete and then (status.all = status_$ok) then begin
      ml_$lock(ml_$ast_lock);
      aote := ast_$lookup_aote_by_uid(local_uid.uid);
      if aote <> nil then begin
        ml_$lock(ml_$pmap_lock);
        aote^.dta := buf.clock;
        aote^.dtm := buf.clock;
        ml_$unlock(ml_$pmap_lock);
      end;
      ml_$unlock(ml_$ast_lock);
    end;
    proc1_$inhibit_end;
    return;
  end;

  { the failure tails }
60:
  ec_$advance(ast_$ast_in_trans_ec);
70:
  ml_$unlock(ml_$ast_lock);
80:
  proc1_$inhibit_end;
90:
  status := local_status;
end;
