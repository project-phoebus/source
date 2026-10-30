{ area_$internal_delete - delete an area: shrink it to nothing, drop its
  remote backing, and optionally return its entry to the free list.

  Image addresses:
    sau2  0x00E07B50  area_$internal_delete (module-local)
    sau9  0x3C409176  area_$internal_delete (module-local)

  - An active entry's area is shrunk to zero (area_$resize), its remote
    volume deleted at the diskless partner, and the entry marked
    inactive.
  - With unlink, under the area lock, it also leaves its address space's
    list and goes on AREA_$FREE_LIST.
  - The frame has 4 bytes no object explains (area/area.pas's frames
    TODO).

  Status stored:
    status_$ok: the area was deleted, or the entry is not active
    area_$resize's or rem_file_$delete_area's status: those failed
}

procedure area_$internal_delete(var entry: area_$entry_t; area_id: integer;
                                out status: status_$t; unlink: boolean);
begin
  status.all := status_$ok;
  if not (area_$f_active in entry.flags) then
    return;

  { the segments }
  if entry.virt_size <> 0 then begin
    area_$resize(area_id, entry, 0, 0, 0, status);
    if status.all <> status_$ok then
      return;
  end;

  { the remote backing }
  if entry.remote_volx <> 0 then begin
    rem_file_$delete_area(area_$partner, entry.remote_volx,
                          entry.caller_id, status);
    if status.all <> status_$ok then
      return;
  end;

  entry.flags := entry.flags - [area_$f_active];

  { back on the free list }
  if unlink then begin
    ml_$lock(ml_$area_lock);
    entry.flags := entry.flags - [area_$f_in_trans];
    if entry.next <> nil then
      entry.next^.prev := entry.prev;
    if entry.prev <> nil then
      entry.prev^.next := entry.next
    else
      area_$asid_list[entry.owner_asid] := entry.next;
    entry.next := area_$free_list;
    entry.prev := nil;
    area_$free_list := addr(entry);
    area_$n_free := area_$n_free + 1;
    ml_$unlock(ml_$area_lock);
  end;
end;
