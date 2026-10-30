{ acl_$cache_list_remove - unlink a cache slot from a circular list.

  Image addresses:
    sau2  0x00E44C92  acl_$cache_list_remove (module-local)

  - The slot's neighbors are linked to each other; a head slot moves the
    head to the next, or empties a one-slot list.  The slot's own link
    is left.

  Status stored: none.
}

procedure acl_$cache_list_remove(in out head: integer;
                                 var links: acl_$cache_links_t;
                                 slot: integer); internal;
var
  next: integer;
  prev: integer;
begin
  if head = acl_cache_no_slot then
    return;

  next := links[slot].next;
  prev := links[slot].prev;
  links[next].prev := prev;
  links[prev].next := next;

  if slot = head then
    if slot = next then
      head := acl_cache_no_slot
    else
      head := next;
end;
