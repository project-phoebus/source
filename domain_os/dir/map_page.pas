{ dir_$map_page - the address of one page of a directory, through the
  handle's two-slot page cache.

  Image addresses:
    sau2  0x00E4B340  dir_$map_page

  - A handle maps its directory in groups of 32 pages, one group per
    cache slot; the result is the slot's base plus (page mod 32) * 1024.
  - On a miss in both slots the current one, or the other if the
    current holds the wired page, is remapped (MST_$REMAP_PRIVI); a
    failure, or a mapping of another size, crashes the system.

  Status stored: none.
}

function dir_$map_page(var handle: dir_$handle_t; page: pinteger): univ_ptr;
  internal;
var
  map_len: integer32;
  local_status: status_$t;
  offset: integer32;
begin
  { the current slot }
  if handle.map.slot[handle.cur_slot].group = page div 32 then begin
    dir_$map_page := univ_ptr(handle.map.slot[handle.cur_slot].base +
                              (page mod 32) * 1024);
    return;
  end;

  { the other slot }
  handle.cur_slot := xor(handle.cur_slot, 1);
  if handle.map.slot[handle.cur_slot].group = page div 32 then begin
    dir_$map_page := univ_ptr(handle.map.slot[handle.cur_slot].base +
                              (page mod 32) * 1024);
    return;
  end;

  { never the wired page's slot }
  if handle.cur_slot = handle.max_slots then
    handle.cur_slot := xor(handle.cur_slot, 1);

  with handle.map.slot[handle.cur_slot] do begin
    { remap the slot }
    group := page div 32;
    offset := group * 16#8000;
    base := integer32(mst_$remap_privi(1, base, 16#8000, offset, 16#8000,
                                       map_len, local_status));

    if local_status.all <> status_$ok then
      crash_system(local_status);

    if map_len <> 32768 then
      crash_system(status_$naming_internal_error);

    dir_$map_page := univ_ptr(base + (page mod 32) * 1024);
  end;
end;
