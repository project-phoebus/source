{ AREA_$TRANSFER - give an area to another address space.

  Image addresses:
    sau2  0x00E08098  AREA_$TRANSFER
    sau9  0x3C4096B0  AREA_$TRANSFER

  - Under the area lock, after waiting out any operation in transition,
    the entry is held in transition.
  - A smaller new size shrinks the area first; under the PMAP lock the
    entry takes the new address space's first segment-table word and
    index; a larger size grows it after.
  - On success the entry moves to the new address space's list and the
    result is the area's old first segment index; a failed growth puts
    the old address space and index back.
  - With the large VM layout the new address space's BST entries for
    the area's segments link to the old segments, under the PMAP lock;
    a failed growth sets them to none.
  - A failure does not assign the result.

  Status stored:
    status_$ok: the area was transferred
    status_$area_not_active: an id outside 1..AREA_$N_AREAS, or an
      inactive entry
    status_$area_not_owner: another address space's entry
    area_$resize's status: a resize failed
}

function area_$transfer(var handle: univ area_$handle_t; new_asid: integer;
                        new_seg_idx: integer; new_virt_size: linteger;
                        out status: status_$t): integer;
label
  10, 20;
var
  status_l: status_$t;
  entry: area_$entry_ptr_t;
  old_virt_size: linteger;
  old_seg_idx: integer;
  seg_count: integer;
  seg_adj: integer;
%if large_vm %then
  first: pinteger;
  last: integer;
  i: integer;
%endif
begin
  if (handle.area_id = 0) or else (handle.area_id > area_$n_areas) then
  begin
    status.all := status_$area_not_active;
    return;
  end;

  entry := addr(areas[handle.area_id]);
  status_l.all := status_$ok;
  ml_$lock(ml_$area_lock);
  while area_$f_in_trans in entry^.flags do
    area_$wait_in_trans;

  if not (area_$f_active in entry^.flags) then
    status_l.all := status_$area_not_active
  else if entry^.owner_asid <> proc1_$as_id then
    status_l.all := status_$area_not_owner
  else begin
    entry^.flags := entry^.flags + [area_$f_in_trans];
    ml_$unlock(ml_$area_lock);

    { a smaller size first }
    old_virt_size := entry^.virt_size;
    if new_virt_size < old_virt_size then begin
      area_$resize(handle.area_id, entry^, new_virt_size,
                   entry^.commit_size, 1, status_l);
      if status_l.all <> status_$ok then
        goto 10;
    end;

    { the new address space's segments }
    ml_$lock(ml_$pmap_lock);
    seg_count := rshft(entry^.virt_size + 16#7FFF, 15);
    with entry^ do begin
      old_seg_idx := first_seg_index;
      first_bste := new_asid;
      first_seg_index := new_seg_idx;
%if large_vm %then
      first := new_seg_idx;
%endif
      if area_$f_reversed in flags then begin
        seg_adj := seg_count - 1;
%if large_vm %then
        { a reversed area's BST run starts seg_adj below new_seg_idx }
        first := first - seg_adj;
%endif
        first_seg_index := first_seg_index + seg_adj;
      end;
    end;
%if large_vm %then
    { the new segments' BST links, to the old segments }
    last := seg_count - 1;
    for i := old_seg_idx to old_seg_idx + last do begin
      bst[first + bst_asid_base[new_asid] + (i - old_seg_idx)].asid :=
        proc1_$as_id;
      bst[first + bst_asid_base[new_asid] + (i - old_seg_idx)].seg := i;
    end;
%endif
    ml_$unlock(ml_$pmap_lock);

    { a larger size after }
    if new_virt_size > old_virt_size then begin
      area_$resize(handle.area_id, entry^, new_virt_size,
                   entry^.commit_size, 1, status_l);
      if status_l.all <> status_$ok then begin
        ml_$lock(ml_$pmap_lock);
        with entry^ do begin
%if large_vm %then
          for i := 0 to last do
            bst[first + bst_asid_base[new_asid] + i].asid := -1;
%endif
          first_bste := proc1_$as_id;
          first_seg_index := old_seg_idx;
        end;
        ml_$unlock(ml_$pmap_lock);
        goto 10;
      end;
    end;

    { from the old list to the new }
    ml_$lock(ml_$area_lock);
    if entry^.next <> nil then
      entry^.next^.prev := entry^.prev;
    if entry^.prev <> nil then
      entry^.prev^.next := entry^.next
    else
      area_$asid_list[entry^.owner_asid] := entry^.next;
    entry^.next := area_$asid_list[new_asid];
    if entry^.next <> nil then
      entry^.next^.prev := entry;
    entry^.prev := nil;
    area_$asid_list[new_asid] := entry;
    entry^.owner_asid := new_asid;
    area_$transfer := old_seg_idx;
    goto 20;

    { a failure's relock }
  10:
    ml_$lock(ml_$area_lock);

  20:
    entry^.flags := entry^.flags - [area_$f_in_trans];
    ec_$advance(area_$in_trans_ec);
  end;

  ml_$unlock(ml_$area_lock);
  status := status_l;
end;
