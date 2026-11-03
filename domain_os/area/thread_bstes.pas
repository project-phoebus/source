{ AREA_$THREAD_BSTES - record an area's first BSTE and segment index.

  Image addresses:
    sau2  0x00E09722  AREA_$THREAD_BSTES
    sau4  0x0F809DAA  AREA_$THREAD_BSTES
    sau9  0x3C40B090  AREA_$THREAD_BSTES

  - Under the area lock, after waiting out any operation in transition,
    an entry with no first BSTE yet (-1) gets asid and seg_idx (the
    area's last segment for a reversed area) as its first segment, with
    the entry held in transition.
  - With the large VM layout, under the PMAP lock: a new first segment's
    BST entries, one per segment of the area, are set to none; an entry
    threaded already has the BST links of count segments, from area_seg
    on, moved to address space asid's segments from seg_idx on, each old
    link pointing at its new place.

  Status stored:
    status_$ok: the BSTE was recorded, or the entry had one
    status_$area_not_active: an id outside 1..AREA_$N_AREAS, an entry
      not active or of another generation
}

procedure area_$thread_bstes(var handle_ptr: area_$handle_t;
                             asid: integer; seg_idx: pinteger;
                             count: integer; area_seg: pinteger;
                             out status_ret: status_$t);
var
  entry: area_$entry_ptr_t;
  n: pinteger;
%if large_vm %then
  link: ^mst_$pmap_link_t;
  i: integer;
%endif
begin
  if (handle_ptr.area_id = 0) or else
     (handle_ptr.area_id > area_$n_areas) then begin
    status_ret.all := status_$area_not_active;
    return;
  end;

  entry := addr(areas[handle_ptr.area_id]);
  ml_$lock(ml_$area_lock);
  while area_$f_in_trans in entry^.flags do
    area_$wait_in_trans;

  if (not (area_$f_active in entry^.flags)) or else
     (handle_ptr.generation <> entry^.generation) then
    status_ret.all := status_$area_not_active
  else begin
    entry^.flags := entry^.flags + [area_$f_in_trans];
    ml_$unlock(ml_$area_lock);
    status_ret.all := status_$ok;
    with entry^ do
%if large_vm %then
      if first_bste = -1 then begin
        first_bste := asid;
        n := rshft(virt_size + 16#7FFF, 15);
        ml_$lock(ml_$pmap_lock);
        { the new segments' BST entries: none }
        if area_$f_reversed in flags then begin
          seg_idx := seg_idx + n - 1;
          first_seg_index := seg_idx;
          for i := 1 to n do begin
            bst[seg_idx + bst_asid_base[first_bste]].asid := -1;
            seg_idx := seg_idx - 1;
          end;
        end
        else begin
          first_seg_index := seg_idx;
          for i := 1 to n do begin
            bst[seg_idx + bst_asid_base[first_bste]].asid := -1;
            seg_idx := seg_idx + 1;
          end;
        end;
        ml_$unlock(ml_$pmap_lock);
      end
      else begin
        { the threaded segments' links, to their new places }
        if area_$f_reversed in flags then
          area_seg := first_seg_index - (-1 - area_seg)
        else
          area_seg := first_seg_index + area_seg;
        if (asid <> owner_asid) or else (area_seg <> seg_idx) then begin
          ml_$lock(ml_$pmap_lock);
          for i := 1 to count do begin
            link := addr(bst[area_seg + bst_asid_base[first_bste]]);
            bst[seg_idx + bst_asid_base[asid]] := link^;
            link^.asid := asid;
            link^.seg := seg_idx;
            area_seg := area_seg + 1;
            seg_idx := seg_idx + 1;
          end;
          ml_$unlock(ml_$pmap_lock);
        end;
      end;
%else
      if first_bste = -1 then begin
        first_bste := asid;
        n := rshft(virt_size + 16#7FFF, 15);
        if area_$f_reversed in flags then
          seg_idx := seg_idx + n - 1;
        first_seg_index := seg_idx;
      end;
%endif
    ml_$lock(ml_$area_lock);
    entry^.flags := entry^.flags - [area_$f_in_trans];
    ec_$advance(area_$in_trans_ec);
  end;

  ml_$unlock(ml_$area_lock);
end;
