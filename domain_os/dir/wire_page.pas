{ dir_$wire_page - wire one mapped page of a handle's directory.

  Image addresses:
    sau2  0x00E4B7B6  dir_$wire_page

  - A handle wires at most one page; max_slots becomes the cache slot
    whose 32768-byte group holds the page, so dir_$map_page never reuses
    it.
  - A page wired already, a failed MST_$WIRE or a page in neither slot
    crashes the system.

  Status stored: none.
}

procedure dir_$wire_page(var handle: dir_$handle_t; page: univ_ptr);
  internal;
var
  local_status: status_$t;
begin
  { one wired page at a time }
  if handle.max_slots <> 2 then
    crash_system(status_$naming_internal_error);

  handle.buf := page;
  handle.wired_page := mst_$wire(integer32(page), local_status);

  if local_status.all <> status_$ok then
    crash_system(local_status);

  { the slot that holds it }
  if (integer32(page) & (-16#8000)) = handle.map.slot[0].base then
    handle.max_slots := 0
  else if (integer32(page) & (-16#8000)) = handle.map.slot[1].base then
    handle.max_slots := 1
  else
    crash_system(status_$naming_internal_error);
end;
