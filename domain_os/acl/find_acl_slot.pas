{ acl_$find_acl_slot - find an ACL's cache slot, loading its image on a
  miss.

  Image addresses:
    sau2  0x00E45E8E  acl_$find_acl_slot (module-local)

  - The UID's hash chain (UID_$HASH mod 61) is searched; a hit gives the
    slot's cached flag, a default ACL's record rebuilt.  A miss loads
    the image (acl_$load_acl_image).
  - The slot found goes to the LRU list's head; the result is the slot.

  Status stored:
    status_$ok: a hit
    acl_$load_acl_image's status: a miss
}

function acl_$find_acl_slot(var acl_uid: uid_$t; var cached: boolean;
                            var prot: acl_$prot_data_t;
                            out status: status_$t): integer; internal;
label
  10;
var
  def_acl_uid: uid_$t;
  slot: integer;
  hash: integer;
begin
  status.all := status_$ok;

  hash := uid_$hash(acl_uid, 61);
  slot := acl_$cache_hash_buckets[hash];

  repeat
    if slot = acl_cache_no_slot then begin
      slot := acl_$load_acl_image(acl_uid, cached, prot, status);
      if status.code <> 0 then begin
        acl_$find_acl_slot := slot;
        return;
      end;
      if slot = acl_cache_no_slot then begin
        acl_$find_acl_slot := slot;
        return;
      end;
      goto 10;
    end;
    if acl_$cache_dir[slot].acl_uid = acl_uid then begin
      cached := acl_$cache_dir[slot].cached_flag;
      if cached then begin
        acl_$def_acldata(prot, def_acl_uid);
        prot.world_rights :=
          acl_$rights_t(acl_$cache_dir[slot].world_rights);
        prot.subsys_rights :=
          acl_$rights_t(acl_$cache_dir[slot].subsys_rights);
      end;
    end
    else begin
      slot := acl_$cache_hash_links[slot].next;
      if slot = acl_$cache_hash_buckets[hash] then
        slot := acl_cache_no_slot;
      next;
    end;
    acl_$cache_list_remove(acl_$cache_lru_head, acl_$cache_lru_links,
                           slot);
    exit;
  until false;

10:
  acl_$cache_list_insert(acl_$cache_lru_head, acl_$cache_lru_links, slot);
  acl_$find_acl_slot := slot;
end;
