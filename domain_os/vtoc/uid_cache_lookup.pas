{ vtoc_$uid_cache_lookup - find where a UID's VTOCE lies.

  Image addresses:
    sau2  0x00E38324  vtoc_$uid_cache_lookup (module-local)

  - A valid entry of the bucket holding the UID is found (its age reset,
    or with remove its volume cleared and age 65535); every other entry
    ages by one, up to 65534.  The result is whether one was found.
  - With remove, flags returns the cleared volume, 0.

  Status stored: none.
}

function vtoc_$uid_cache_lookup(in uid: univ vtoc_$uid_view_t;
                                out flags: integer;
                                out block_info: fm_$block_addr_t;
                                remove: boolean): boolean;
  internal;
var
  found: boolean;
  bucket: pinteger;
  j: integer;                             { the loop }
begin
  found := false;
  bucket := uid.high_lo mod 101;

  for j := 0 to 3 do
    if (vtoc_$uid_cache[bucket].entries[j].uid = uid.uid) and then
       (vtoc_$uid_cache[bucket].entries[j].vol <> 0) then begin
      found := true;
      if remove then begin
        vtoc_$uid_cache[bucket].entries[j].vol := 0;
        vtoc_$uid_cache[bucket].entries[j].age := 16#FFFF;
      end
      else
        vtoc_$uid_cache[bucket].entries[j].age := 0;
      flags := vtoc_$uid_cache[bucket].entries[j].vol;
      block_info := vtoc_$uid_cache[bucket].entries[j].block_info;
    end
    else if vtoc_$uid_cache[bucket].entries[j].age < 16#FFFE then
      vtoc_$uid_cache[bucket].entries[j].age :=
        vtoc_$uid_cache[bucket].entries[j].age + 1;

  vtoc_$uid_cache_lookup := found;
end;
