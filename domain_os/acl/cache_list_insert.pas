{ acl_$cache_list_insert - link a cache slot in at a circular list's head.

  Image addresses:
    sau2  0x00E44C3C  acl_$cache_list_insert (module-local)

  - The cache's lists (LRU, hash chains, free) are circular and doubly
    linked through acl_$cache_lru_links and acl_$cache_hash_links.
  - The slot goes in before the head (links to itself in an empty list,
    head -1) and becomes the head.

  Status stored: none.
}

procedure acl_$cache_list_insert(in out head: integer;
                                 var links: acl_$cache_links_t;
                                 slot: integer); internal;
var
  tail: integer;
begin
  if head <> acl_cache_no_slot then begin
    tail := links[head].prev;
    links[head].prev := slot;
    links[tail].next := slot;
    links[slot].next := head;
    links[slot].prev := tail;
  end
  else begin
    links[slot].next := slot;
    links[slot].prev := slot;
  end;
  head := slot;
end;
