{ AREA_$TOUCH - fault one page of an area in, growing its commitment.

  Image addresses:
    sau2  0x00E094FE  AREA_$TOUCH
    sau4  0x0F809B12  AREA_$TOUCH
    sau9  0x3C40ADDE  AREA_$TOUCH

  - Under the area lock, after waiting out any operation in transition,
    the page's segment's ASTE is found and wired
    (area_$find_entry_by_uid).
  - A page past the committed size grows the area by at least four
    pages, within its virtual size (area_$resize).
  - With the large VM layout the current address space's map entry for
    seg_index is made valid on the ASTE's page map, unless the caller is
    a page server.
  - AST_$TOUCH_AREA then faults the page in under the PMAP lock; the
    entry is marked touched.
  - Every path returns holding the PMAP lock; the caller releases it.

  Status stored:
    ast_$touch_area's status: the page was touched, or not
    status_$area_not_active: an id outside 1..AREA_$N_AREAS, or an
      inactive entry of another generation and no remote UID
    area_$find_entry_by_uid's or area_$resize's status: those failed
}

procedure area_$touch(var handle_ptr: area_$handle_t; bste_idx: pinteger;
                      seg_idx: pinteger; seg_index: pinteger;
                      var ppn_array: univ ast_$ppn_list_t;
                      out status_p: status_$t);
label
  10;
var
  entry: area_$entry_ptr_t;
  aste: ast_$aste_ptr_t;
  needed: integer32;
  grow: linteger;
%if large_vm %then
  smap: ^mst_smap_t;
%endif
begin
  if (handle_ptr.area_id = 0) or else
     (handle_ptr.area_id > area_$n_areas) then begin
    status_p.all := status_$area_not_active;
    goto 10;
  end;

  entry := addr(areas[handle_ptr.area_id]);
  ml_$lock(ml_$area_lock);
  while area_$f_in_trans in entry^.flags do
    area_$wait_in_trans;

  if (not (area_$f_active in entry^.flags)) or else
     ((entry^.generation <> handle_ptr.generation) and then
      (entry^.remote_uid = 0)) then begin
    ml_$unlock(ml_$area_lock);
    status_p.all := status_$area_not_active;
    goto 10;
  end;

  ml_$unlock(ml_$area_lock);
  aste := area_$find_entry_by_uid(handle_ptr.area_id, bste_idx, seg_idx,
                                  status_p);
  if status_p.all <> status_$ok then
    goto 10;

%if large_vm %then
  { the segment's map entry onto the ASTE's page map }
  if proc1_$type[proc1_$current] <> area_page_server_type then begin
    smap := addr(smaps[seg_index + smap_asid_base[proc1_$as_id]]);
%if region_mmu %then
    if not smap^.e.valid then begin
      ml_$lock(ml_$pmap_lock);
      smap^.e.pmap_pa := aste^.pmap_pa;
      smap^.bits := smap^.bits + [31];
      ml_$unlock(ml_$pmap_lock);
    end;
%else
    if smap^.ctl.dt <> mst_smap_valid then begin
      ml_$lock(ml_$pmap_lock);
      smap^.table := (smap^.table & 15) + aste^.pmap_pa;
      smap^.lim.limit := 31;
      smap^.ctl.dt := mst_smap_valid;
      smap^.flags := smap^.flags - [9];
      smap^.flags := smap^.flags + [10..15];
      ml_$unlock(ml_$pmap_lock);
    end;
%endif
  end;

%endif
  { the pages needed past the commitment }
  if area_$f_reversed in entry^.flags then
    needed := lshft(bste_idx, 5) + 31 - seg_idx -
              rshft(entry^.commit_size, 10) + 1
  else
    needed := lshft(bste_idx, 5) + seg_idx -
              rshft(entry^.commit_size, 10) + 1;

  { grow the area, at least four pages }
  if needed > 0 then begin
    grow := max(4, needed);
    area_$resize(handle_ptr.area_id, entry^, entry^.virt_size,
                 min(lshft(grow, 10) + entry^.commit_size,
                     entry^.virt_size),
                 1, status_p);
    if status_p.all <> status_$ok then begin
      aste^.wire_count := aste^.wire_count - 1;
      goto 10;
    end;
  end;

  ml_$lock(ml_$pmap_lock);
  ast_$touch_area(handle_ptr.area_id, aste^.seg_index, seg_idx,
                  lshft(bste_idx, 5) + seg_idx, ppn_array, status_p);
  entry^.flags := entry^.flags + [area_$f_touched];
  aste^.wire_count := aste^.wire_count - 1;
  return;

  { every failure takes the PMAP lock too }
10:
  ml_$lock(ml_$pmap_lock);
end;
