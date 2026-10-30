{ FILE_$SET_ATTRIBUTE - set one attribute of an object, locally or on its
  home node.

  Image addresses:
    sau2  0x00E5D242  FILE_$SET_ATTRIBUTE

  - A remote object's home node sets the attribute
    (REM_FILE_$FILE_SET_ATTRIB), unless the hint cache says to treat it
    as local; success updates the local copy (AST_$SET_ATTR).
  - "No rights", "bad reply" and "insufficient rights" fall to the local
    path.
  - The local path checks the rights asked for (ACL_$RIGHTS) and sets
    the attribute (AST_$SET_ATTRIBUTE).

  Status stored:
    ast_$set_attribute's or ast_$set_attr's status: the attribute was
      set, or not
    ast_$get_location's status: the object could not be located
    acl_$get_exsid's or rem_file_$file_set_attrib's status: those failed
    acl_$rights's status, made a FILE_ status: no rights granted
}

procedure file_$set_attribute(in file_uid: uid_$t; attr_id: integer;
                              in value: file_$attr_value_t;
                              rights: pinteger; options: integer;
                              out status_ret: status_$t);
var
  loc: file_$obj_loc_t;
  unused: integer32;
  location: ast_$location_t;
  loc_status: status_$t;
  mtime: time_$clock_t;
  exsid: acl_$exsid_t;
  in_cache: boolean;
  rights_result: integer;
begin
  { the object's location }
  loc.uid := file_uid;
  loc.flags := loc.flags - [6];
  ast_$get_location(loc, 0, unused, location, loc_status);
  if loc_status.all <> status_$ok then begin
    status_ret := loc_status;
    return;
  end;

  { a remote object }
  if 7 in loc.flags then begin
    acl_$get_exsid(exsid, status_ret);
    if status_ret.all <> status_$ok then
      return;
    hint_$lookup_cache(loc.uid.low & 16#FFFFF, in_cache);
    if not in_cache then begin
      rem_file_$file_set_attrib(loc.loc_info, file_uid, value, attr_id,
                                exsid, rights, options, mtime, status_ret);
      if (status_ret.all <> status_$no_rights) and then
         (status_ret.all <> file_$bad_reply_received_from_remote_node)
         and then
         (status_ret.all <> status_$insufficient_rights) then begin
        if status_ret.all = status_$ok then
          ast_$set_attr(file_uid, attr_id, value, false, mtime,
                        status_ret);
        return;
      end;
    end;
  end;

  { the rights asked for }
  if rights <> 0 then begin
    rights_result := acl_$rights(file_uid, false, rights, options,
                                 status_ret);
    if rights_result = 0 then begin
      os_proc_shutwired(status_ret);
      return;
    end;
  end;

  ast_$set_attribute(file_uid, attr_id, value, status_ret);
end;
