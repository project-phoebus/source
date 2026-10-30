{ dir_$unmap_pages - give up a handle's mapping of its directory.

  Image addresses:
    sau2  0x00E4B6BA  dir_$unmap_pages

  - A directory the handle mapped itself is unmapped (MST_$UNMAP_PRIVI),
    in one call when the two slots are adjacent, its status never looked
    at; one of NAME's four well-known directories gives its mapping
    record back to NAME.

  Status stored: none.
}

procedure dir_$unmap_pages(var handle: dir_$handle_t);
  internal;
var
  local_status: status_$t;
  size: integer32;
begin
  if handle.map.info.active then begin
    if handle.dir_kind = 0 then begin
      if handle.map.slot[0].base + 16#8000 = handle.map.slot[1].base then
        size := 65536
      else
        size := 32768;

      mst_$unmap_privi(3, handle.uid, handle.map.slot[0].base, size,
                       proc1_$as_id, local_status);

      if size = 32768 then
        mst_$unmap_privi(3, handle.uid, handle.map.slot[1].base, 16#8000,
                         proc1_$as_id, local_status);
    end

    { back to NAME's record }
    else if handle.dir_kind = 1 then
      name_$node_mapped_info := handle.map.info
    else if handle.dir_kind = 2 then
      name_$com_mapped_info := handle.map.info
    else if handle.dir_kind = 3 then
      name_$wdir_mapped_info[proc1_$as_id] := handle.map.info
    else if handle.dir_kind = 4 then
      name_$ndir_mapped_info[proc1_$as_id] := handle.map.info;

    handle.map.info.active := false;
  end;
end;
