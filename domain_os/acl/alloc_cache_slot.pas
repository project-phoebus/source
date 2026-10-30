{ acl_$alloc_cache_slot - take a cache slot, from the free list or the
  least recently used.

  Image addresses:
    sau2  0x00E458E4  acl_$alloc_cache_slot (module-local)

  - A free slot first, else the LRU list's tail, taken off the LRU list
    and its hash chain; with neither the system crashes (16#00230000).
  - The result is the slot.

  Status stored:
    status_$ok: always
}

function acl_$alloc_cache_slot(out status_ret: status_$t): integer;
  internal;
var
  slot: integer;
  victim: integer;
begin
  status_ret.all := status_$ok;

  if acl_$cache_free_head <> acl_cache_no_slot then begin
    slot := acl_$cache_free_head;
    acl_$cache_list_remove(acl_$cache_free_head, acl_$cache_hash_links,
                           acl_$cache_free_head);
  end
  else begin
    if acl_$cache_lru_head = acl_cache_no_slot then
      crash_system(16#00230000);

    { the LRU list's tail }
    victim := acl_$cache_lru_links[acl_$cache_lru_head].prev;
    acl_$cache_list_remove(acl_$cache_lru_head, acl_$cache_lru_links,
                           victim);
    slot := acl_$cache_dir[victim].hash_bucket;
    acl_$cache_list_remove(acl_$cache_hash_buckets[slot],
                           acl_$cache_hash_links, victim);
    slot := victim;
  end;

  acl_$alloc_cache_slot := slot;
end;
