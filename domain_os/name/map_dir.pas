{ name_$map_dir - map a directory for NAME's quick access.

  Image addresses:
    sau2  0x00E58488  name_$map_dir

  - The mapping is marked inactive; a local directory is mapped, 65536
    bytes (MST_$MAPS; another length crashes the system), and recorded
    active, its second half 32768 bytes after the first.
  - The result is whether it was mapped.
  - A failed map leaves its address in first_base; a remote directory
    gives false with AST_$GET_LOCATION's status.

  Status stored:
    mst_$maps' status: the directory is local
    ast_$get_location's status: it failed, or the directory is remote
}

function name_$map_dir(dir_uid: uid_$t; asid: integer;
                       out mapped_info: name_$mapped_info_t;
                       out status: status_$t): boolean;
  internal;
var
  loc_rec: file_$obj_loc_t;
  local_status: status_$t;
  map_len: integer32;
  unused: integer32;
  location: ast_$location_t;
begin
  mapped_info.active := false;
  name_$map_dir := false;
  loc_rec.uid := dir_uid;
  loc_rec.flags := loc_rec.flags - [6];
  ast_$get_location(loc_rec, 0, unused, location, local_status);

  if (local_status.all <> status_$ok) or else
     (location.location_hi < 0) then
    status := local_status
  else begin
    mapped_info.first_base := integer32(mst_$maps(asid, true, dir_uid, 0,
                                                  65536, 16#16, 0, true,
                                                  map_len, status));
    if status.code = 0 then begin
      if map_len <> 65536 then
        crash_system(status_$naming_internal_error);
      mapped_info.active := true;
      name_$map_dir := true;
      mapped_info.reserved_02 := 0;
      mapped_info.entry_count := 1;
      mapped_info.second_base := mapped_info.first_base + 16#8000;
    end;
  end;
end;
