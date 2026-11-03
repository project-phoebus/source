{ AREA_$REMOVE_SEG - take one segment out of an area.

  Image addresses:
    sau2  0x00E09822  AREA_$REMOVE_SEG
    sau4  0x0F809FCA  AREA_$REMOVE_SEG
    sau9  0x3C40B29C  AREA_$REMOVE_SEG

  - Under the area lock, after waiting out any operation in transition,
    an active entry of the handle's generation is held in transition.
  - asid and seg_index name the segment in its address space, area_seg
    its number within the area.
  - A segment that is the whole area deletes the area; otherwise a
    segment holding pages has its ASTE's installed pages taken out of
    the MMU (MMU_$REMOVE_LIST) and its wire count dropped.
  - With the large VM layout the segment's map entry is made invalid
    when release is clear or the area goes, and instead of the pages'
    removal the segment's link leaves the BST thread of the area's
    segment, under the PMAP lock.

  Status stored:
    status_$ok: the segment was taken out, or there was nothing to do
    status_$area_not_active: an id outside 1..AREA_$N_AREAS
    area_$internal_delete's or area_$find_entry_by_uid's status: those
      failed
}

procedure area_$remove_seg(var seg_rec: area_$handle_t; asid: integer;
                           seg_index: pinteger; release: boolean;
                           area_seg: pinteger; out status_ret: status_$t);
%if not large_vm %then
label
  10;
type
  segmap_ptr_t = ^ast_$pmap_t;
%endif
var
  entry: area_$entry_ptr_t;
%if not large_vm %then
  seg: pinteger;
%endif
%if large_vm %then
  neg_seg: pinteger;
%else
  neg_seg: integer;
%endif
  last_seg: pinteger;
  whole: boolean;
%if large_vm %then
  link: ^mst_$pmap_link_t;
  next_link: mst_$pmap_link_t;
%else
  lim: linteger;
  pos: linteger;
  seg_word: pinteger;
  aste: ast_$aste_ptr_t;
  segmap: segmap_ptr_t;
  list: ast_$ppn_list_t;
  count: integer;
  i: integer;                             { the `for''s count }
%endif
begin
  status_ret.all := status_$ok;
  if (seg_rec.area_id = 0) or else (seg_rec.area_id > area_$n_areas) then
  begin
    status_ret.all := status_$area_not_active;
    return;
  end;

  entry := addr(areas[seg_rec.area_id]);
  ml_$lock(ml_$area_lock);
  while area_$f_in_trans in entry^.flags do
    area_$wait_in_trans;

  if (area_$f_active in entry^.flags) and then
     (seg_rec.generation = entry^.generation) then begin
    entry^.flags := entry^.flags + [area_$f_in_trans];
    ml_$unlock(ml_$area_lock);

    { is the segment the whole area? }
    with entry^ do begin
%if not large_vm %then
      seg := area_seg;
%endif
      if area_$f_reversed in flags then begin
        neg_seg := -1 - area_seg;
        if virt_size = 0 then
          last_seg := 0
        else
          last_seg := rshft(virt_size + 16#7FFF, 15) - 1;
        whole := (asid = owner_asid) and (last_seg = neg_seg) and
                 (first_seg_index = last_seg + seg_index) and release;
      end
      else
        whole := (asid = owner_asid) and (area_seg = 0) and
                 (seg_index = first_seg_index) and release;
    end;

%if large_vm %then
    if not release then
%if region_mmu %then
      smaps[seg_index + smap_asid_base[asid]].bits :=
        smaps[seg_index + smap_asid_base[asid]].bits - [31];
%else
      smaps[seg_index + smap_asid_base[asid]].ctl.dt := mst_smap_invalid;
%endif
%endif
    if whole then begin
%if large_vm %then
%if region_mmu %then
      smaps[seg_index + smap_asid_base[asid]].bits :=
        smaps[seg_index + smap_asid_base[asid]].bits - [31];
%else
      smaps[seg_index + smap_asid_base[asid]].ctl.dt := mst_smap_invalid;
%endif
%endif
      area_$internal_delete(entry^, seg_rec.area_id, status_ret, true);
      ec_$advance(area_$in_trans_ec);
      return;
    end;

%if large_vm %then
    { the segment's link, out of the thread that starts at the area's
      segment }
    ml_$lock(ml_$pmap_lock);
    if area_$f_reversed in entry^.flags then
      link := addr(bst[entry^.first_seg_index +
                       bst_asid_base[entry^.first_bste] - neg_seg])
    else
      link := addr(bst[entry^.first_seg_index +
                       bst_asid_base[entry^.first_bste] + area_seg]);
    while link^.asid <> -1 do begin
      if (link^.asid = asid) and then (link^.seg = seg_index) then begin
        next_link := bst[link^.seg + bst_asid_base[link^.asid]];
        bst[link^.seg + bst_asid_base[link^.asid]].asid := -1;
        link^ := next_link;
%if region_mmu %then
        smaps[seg_index + smap_asid_base[asid]].bits :=
          smaps[seg_index + smap_asid_base[asid]].bits - [31];
%else
        smaps[seg_index + smap_asid_base[asid]].ctl.dt := mst_smap_invalid;
%endif
        exit;
      end;
      link := addr(bst[link^.seg + bst_asid_base[link^.asid]]);
    end;
    ml_$unlock(ml_$pmap_lock);

%else
    { does the segment hold any of its pages? }
    if area_$f_reversed in entry^.flags then begin
      lim := lshft(16#FFFF - seg, 5) + 31;
      pos := rshft(entry^.virt_size - 1, 10);
      if lim > pos then
        goto 10;
    end
    else begin
      lim := rshft(entry^.virt_size - 1, 10);
      pos := lshft(seg, 5);
      if pos > lim then
        goto 10;
    end;

    seg_word := seg;
    aste := area_$find_entry_by_uid(seg_rec.area_id, seg_word, 0,
                                    status_ret);
    if status_ret.all <> status_$ok then
      goto 10;

    { the installed pages, out of the MMU }
    count := 0;
    segmap := addr(ast_pmaps[aste^.seg_index]);
    ml_$lock(ml_$pmap_lock);
    for i := 0 to 31 do
      with segmap^[i] do
        if (14 in flags) and then (13 in flags) then begin
          flags := flags - [13];
          count := count + 1;
          list[count] := vpn;
        end;

    if count <> 0 then
      mmu_$remove_list(list, count);
    ml_$unlock(ml_$pmap_lock);
    aste^.wire_count := aste^.wire_count - 1;

10:
%endif
    ml_$lock(ml_$area_lock);
    entry^.flags := entry^.flags - [area_$f_in_trans];
    ec_$advance(area_$in_trans_ec);
  end;

  ml_$unlock(ml_$area_lock);
end;
