{ acl_$load_acl_image - load an ACL's image into a cache slot (the
  cache's miss path).

  Image addresses:
    sau2  0x00E45A60  acl_$load_acl_image (module-local)

  - A default ACL needs no slot (the flag set, slot -1, no status
    stored).
  - Otherwise the object is mapped as a super-user and its image copied
    into a slot under a cleanup handler; a failure frees the slot.
  - An image below version 5 is converted; one that carries nothing
    frees the slot and sets the UID nil.  The slot goes into the cache
    directory and its hash chain; the result is the slot.
  - The alloc failure path returns the unassigned result; it cannot be
    taken.

  Status stored:
    acl_$convert_image's or mst_$unmap_privi's status: the image was
      loaded
    acl_$alloc_cache_slot's status: no slot
    status_$acl_object_not_found: the map found no object
    a fault's status: the copy faulted
    mst_$maps' or mst_$unmap_privi's status, fail bit set: the mapping
      failed
}

function acl_$load_acl_image(var acl_uid: uid_$t; out cached: boolean;
                             var prot: acl_$prot_data_t;
                             out status: status_$t): integer; internal;
label
  10, 20, 99;
var
  result: integer;
  conv_len: integer;
  slot: integer;
  map_out: integer32;
  image: acl_$cache_slot_ptr_t;
  saved: status_$t;
  cleanup: fim_$cleanup_rec_t;
  cs: acl_$v4_image_ptr_t;
  i: integer;                             { the count only }
begin
  { a default ACL }
  if acl_$expand_default_acl(acl_uid, prot) then begin
    cached := true;
    result := -1;
    goto 99;
  end;

  slot := acl_$alloc_cache_slot(status);
  if status.code <> 0 then
    goto 99;
  result := slot;

  { map the object as a super-user }
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] + 1;
  image := mst_$maps(proc1_$as_id, true, acl_uid, 0, 1024, 16#12, 0,
                     false, map_out, status);
  acl_$super_count[proc1_$current] := acl_$super_count[proc1_$current] - 1;

  if status.code <> 0 then begin
    if status.all <> status_$mst_object_not_found then
      goto 10;
    status.all := status_$acl_object_not_found;
    goto 20;
  end;

  { the copy, under a cleanup handler }
  saved := fim_$cleanup(cleanup);
  if saved.all = fault_$cleanup_set then begin
    acl_$acl_cache[slot] := image^;
    fim_$rls_cleanup(cleanup);
  end
  else begin
    mst_$unmap_privi(1, acl_uid, integer32(image), 1024, proc1_$as_id,
                     status);
    fim_$pop_signal(cleanup);
    status := saved;
    goto 20;
  end;

  mst_$unmap_privi(1, acl_uid, integer32(image), 1024, proc1_$as_id,
                   status);
  if status.code <> 0 then begin
10:
    status.fail := true;
20:
    acl_$cache_list_insert(acl_$cache_free_head, acl_$cache_hash_links,
                           slot);
    goto 99;
  end;

  { a version-3 image to version 4 }
  cached := false;
  cs := addr(acl_$acl_cache[slot]);
  if cs^.version = 3 then
    with cs^ do begin
      version := 4;
      subsys_uid := type_uid;
      required_uid := uid_$nil;
      owner_slot := 0;
      group_slot := 0;
      org_slot := 0;
      if type_uid <> acl_$dir_acl then
        world_entry_present := false;
      unused_29 := chr(0);
      for i := 1 to 5 do
        reserved_2a[i] := 0;
    end;

  { an image below version 5, converted }
  if cs^.version < 5 then begin
    if cs^.type_uid = acl_$dir_acl then begin
      for i := 1 to cs^.entry_count do
        if (cs^.entries[i].rights & 16#20000000) = 0 then
          cs^.entries[i].rights := cs^.entries[i].rights ! 16#200001E0;
      if not cs^.world_entry_present then
        with cs^.entries[cs^.entry_count] do
          if cs^.entry_count < 22 then
            if (reserved_20 <> 0) or else (org <> uid_$nil) or else
               (person <> uid_$nil) or else (group <> uid_$nil) then begin
              cs^.entry_count := cs^.entry_count + 1;
              with cs^.entries[cs^.entry_count].ids_block do begin
                person := uid_$nil;
                group := uid_$nil;
                org := uid_$nil;
                subsys := uid_$nil;
                reserved_20 := 0;
              end;
              cs^.entries[cs^.entry_count].reserved_24 := 0;
              cs^.entries[cs^.entry_count].rights := 16#1E0;
            end;
    end;

    acl_$convert_image(cs^, prot, acl_$image_buf, conv_len, status);
    image := addr(acl_$image_buf);
    cached := true;
    if (conv_len = 52) and then (image^.required_uid = uid_$nil) and then
       ((image^.subsys_uid = acl_$file_acl) or else
        (image^.subsys_uid = acl_$dir_acl)) then begin
      acl_$cache_list_insert(acl_$cache_free_head, acl_$cache_hash_links,
                             slot);
      result := -1;
      acl_uid := uid_$nil;
      goto 99;
    end;
    acl_$acl_cache[slot] := image^;
  end;

  { the directory and the hash chain }
  acl_$cache_dir[slot].acl_uid := acl_uid;
  acl_$cache_dir[slot].cached_flag := cached;
  if cached then begin
    acl_$cache_dir[slot].world_rights :=
      acl_$rights_byte_t(prot.world_rights);
    acl_$cache_dir[slot].subsys_rights :=
      acl_$rights_byte_t(prot.subsys_rights);
  end;
  acl_$cache_dir[slot].hash_bucket := uid_$hash(acl_uid, 61);
  acl_$cache_list_insert(
    acl_$cache_hash_buckets[acl_$cache_dir[slot].hash_bucket],
    acl_$cache_hash_links, slot);

99:
  acl_$load_acl_image := result;
end;
