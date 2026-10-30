{ vtoc_$uid_cache_insert - remember where a UID's VTOCE lies.

  Image addresses:
    sau2  0x00E382A8  vtoc_$uid_cache_insert (module-local)

  - The UID's bucket (its high longword's low word mod 101): an entry
    holding it ends it; else the oldest entry gets the UID, the location
    and the volume, age 0.

  Status stored: none.
}

procedure vtoc_$uid_cache_insert(in uid: univ vtoc_$uid_view_t;
                                 vol_idx: integer;
                                 block_info: fm_$block_addr_t);
  internal;
var
  bucket: pinteger;
  oldest: pinteger;
  victim: vtoc_$uid_cache_entry_ptr_t;
  j: integer;                             { the loop }
begin
  bucket := uid.high_lo mod 101;
  oldest := 0;
  victim := addr(vtoc_$uid_cache[bucket].entries[0]);

  { the bucket's four entries }
  for j := 0 to 3 do begin
    if (vtoc_$uid_cache[bucket].entries[j].uid = uid.uid) and then
       (vtoc_$uid_cache[bucket].entries[j].vol <> 0) then
      return;
    if oldest < vtoc_$uid_cache[bucket].entries[j].age then begin
      victim := addr(vtoc_$uid_cache[bucket].entries[j]);
      oldest := vtoc_$uid_cache[bucket].entries[j].age;
    end;
  end;

  victim^.uid := uid.uid;
  victim^.block_info := block_info;
  victim^.vol := vol_idx;
  victim^.age := 0;
end;
