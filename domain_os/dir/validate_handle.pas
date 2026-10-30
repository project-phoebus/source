{ dir_$validate_handle - check a handle's object and map its directory.

  Image addresses:
    sau2  0x00E4B44C  dir_$validate_handle

  - The handle takes the directory's length (0 means one page) and
    volume, and a stale block count is cleared (attribute 16#0B).
  - NAME's four well-known directories take NAME's mapping record; any
    other is mapped afresh, 65536 bytes (MST_$MAPS; another size crashes
    the system).  A failure marks the mapping inactive.

  Status stored:
    status_$ok: the handle was mapped (the last step's status)
    ast_$get_common_attributes' status: the attributes could not be read
    status_$naming_directory_object_not_found: "object not found", or a
      remote object
    status_$ast_only_local_access_allowed, fail bit set: an OS-only
      object, to a server process (type 9)
    status_$naming_vol_mounted_read_only: a write open on a read-only
      volume
    name_$file_not_directory: not a directory (sub-type 1 or 2)
    status_$naming_bad_directory: an object of type 0
    ast_$set_attribute's or mst_$maps' status: that step failed
}

procedure dir_$validate_handle(var handle: dir_$handle_t; mode: integer;
                               out status_ret: status_$t);
  internal;
label
  10;
var
  value: file_$attr_value_t;
  loc: file_$obj_loc_t;
  attrs: ast_$common_attr_t;
  map_size: integer32;
  local_status: status_$t;
begin
  loc.uid := handle.uid;
  loc.flags := loc.flags - [6];

  ast_$get_common_attributes(loc, 16#80, attrs, local_status);

  { missing or remote }
  if (local_status.all <> status_$ok) or else (7 in loc.flags) then begin
    status_ret := local_status;
    if (status_ret.all = file_$object_not_found) or else
       (status_ret.all = status_$ok) then
      status_ret.all := status_$naming_directory_object_not_found;
    goto 10;
  end;

  { an OS-only object }
  if (attrs.access_word < 0) and then
     (proc1_$type[proc1_$current] = 9) then begin
    status_ret.all := status_$ast_only_local_access_allowed;
    status_ret.fail := true;
    goto 10;
  end;

  { a write open on a read-only volume }
  if (1 in attrs.attr_flags_lo) and then (mode = 2) then begin
    status_ret.all := status_$naming_vol_mounted_read_only;
    goto 10;
  end;

  if (ord(attrs.sub_type) <> 1) and then (ord(attrs.sub_type) <> 2) then begin
    status_ret.all := name_$file_not_directory;
    goto 10;
  end;

  if ord(attrs.obj_type) = 0 then begin
    status_ret.all := status_$naming_bad_directory;
    goto 10;
  end;

  { a stale block count }
  if attrs.blocks <> 0 then begin
    value.long_val := 0;
    ast_$set_attribute(handle.uid, 16#0B, value, status_ret);
    if status_ret.all <> status_$ok then
      goto 10;
  end;

  if attrs.length = 0 then
    handle.length := 1024
  else
    handle.length := attrs.length;

  handle.volume := loc.volume;

  { NAME's mapped directories }
  if handle.uid = name_$node_uid then begin
    handle.dir_kind := 1;
    handle.map.info := name_$node_mapped_info;
  end
  else if handle.uid = name_$com_uid then begin
    handle.dir_kind := 2;
    handle.map.info := name_$com_mapped_info;
  end
  else if (handle.uid = name_$wdir_uid[proc1_$as_id]) and then
          name_$wdir_mapped_info[proc1_$as_id].active then begin
    handle.dir_kind := 3;
    handle.map.info := name_$wdir_mapped_info[proc1_$as_id];
  end
  else if (handle.uid = name_$ndir_uid[proc1_$as_id]) and then
          name_$ndir_mapped_info[proc1_$as_id].active then begin
    handle.dir_kind := 4;
    handle.map.info := name_$ndir_mapped_info[proc1_$as_id];
  end
  else begin
    { any other directory }
    handle.dir_kind := 0;
    handle.map.slot[0].base := integer32(mst_$maps(proc1_$as_id, true,
                                                   handle.uid, 0, 16#10000,
                                                   16#16, 0, true, map_size,
                                                   status_ret));

    if status_ret.all <> status_$ok then
      goto 10;

    if map_size <> 65536 then
      crash_system(status_$naming_internal_error);

    handle.map.info.active := true;
    handle.map.slot[0].group := 0;
    handle.map.slot[1].group := 1;
    handle.map.slot[1].base := handle.map.slot[0].base + 16#8000;
  end;

  handle.cur_slot := 0;
  return;

10:
  if status_ret.all <> status_$ok then
    handle.map.info.active := false;
end;
