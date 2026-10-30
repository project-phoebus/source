{ ACL_$INIT - initialize the ACL manager.

  Image addresses:
    sau2  0x00E3109C  ACL_$INIT
    sau9  0x3C437204  ACL_$INIT

  - ACL_$DATA is zeroed (44440 bytes), every address space reset
    (ACL_$FREE_ASID) and marked free; process 1 gets the locksmith as
    its login SID and no projects.
  - The 31 cache slots are linked into one ring and ACL_WIRED's
    exclusion lock initialized.

  Status stored: none.
}

{ TODO(pascal) ACL_$INIT's zeroing length, the difference of two addresses

  The length passed to OS_$DATA_ZERO is computed at run time from the
  start of the next load section FILE_$LOT_DATA (the first entry of
  FILE's lock object table) less ACL_$DATA's start.  The source must
  have named an object there and the cache; written here as the address
  of FILE_$LOT_DATA's first byte, declared in acl.pas as an overlay
  variable of that section (`file_$lock_entries', a stand-in, as the map
  gives no symbol there).  An `addr' of an element at a constant index
  fits the image's form (an address inside another unit's object);
  whether the original named FILE's table, an end marker of ACL's own,
  or something else is not known. }

[section(os_init_proc, os_init_data)]
procedure acl_$init;
var
  status: status_$t;
  asid: integer;
  j: integer;                             { the count only }
  i: integer;
begin
  os_$data_zero(acl_$acl_cache,
                integer32(addr(file_$lock_entries[1]))
                - integer32(addr(acl_$acl_cache)));

  { every address space reset and free }
  for asid := 1 to 64 do begin
    acl_$free_asid(asid, status);
    acl_$asid_free_bitmap[asid] := true;
  end;

  { process 1's login SIDs }
  acl_$original_sids[1].login_sid := acl_$locksmith_uid;
  acl_$current_sids[1].login_sid := acl_$locksmith_uid;

  for j := 1 to 8 do
    acl_$proj_uids[1][j] := uid_$nil;

  { the 31 slots in one ring }
  for i := 0 to 30 do begin
    acl_$cache_hash_links[i].next := (i + 1) mod 31;
    acl_$cache_hash_links[i].prev := (31 + i - 1) mod 31;
  end;

  ml_$exclusion_init(acl_$exclusion_lock);
end;
