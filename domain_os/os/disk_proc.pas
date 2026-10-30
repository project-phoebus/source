{ OS_DISK_PROC - forget a volume's entries in VTOC_'s UID cache.

  Image addresses:
    sau2  0x00E3824C  OS_DISK_PROC

  - A volume of 0 forgets every entry; a forgotten entry gets the volume
    0 (invalid) and the age 16#FFFF.
  - A fragment of VTOC_'s module (vtoc/README.md); its address
    also starts the wired range OS_DISK_PROC .. OS_DISK_PROC_END.

  Status stored: none.
}

procedure os_disk_proc(proc_id: integer);
var
  i: integer;                             { the buckets }
  j: integer;                             { the entries }
begin
  for i := 0 to 100 do
    for j := 0 to 3 do
      if (vtoc_$uid_cache[i].entries[j].vol = proc_id) or else
         (proc_id = 0) then begin
        vtoc_$uid_cache[i].entries[j].vol := 0;
        vtoc_$uid_cache[i].entries[j].age := 16#FFFF;
      end;
end;
