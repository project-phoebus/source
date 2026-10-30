{ NAME_$RESOLVE - resolve a pathname to the UID of the object it names.

  Image addresses:
    sau2  0x00E4A258  NAME_$RESOLVE

  - name_$resolve_internal; the result starts as UID_$NIL and on success
    is the object's UID.

  Status stored:
    name_$resolve_internal's status: other than "directory not found in
      pathname"
    name_$not_found: that status
}

{ TODO(pascal) 4 frame bytes of NAME_$RESOLVE no object explains

  The SAU2 frame holds the two UIDs and nothing else addressed: 4 bytes
  are open (stand-in unused_14).  No value parameter is copied
  (path_len is read through its slot), and the call's arguments need no
  temporary. }

procedure name_$resolve(in path: univ name_$long_pname_t;
                        in path_len: integer;
                        out resolved_uid: uid_$t;
                        out status: status_$t);
var
  dir_uid: uid_$t;
  file_uid: uid_$t;
  unused_14: integer32;                   { the TODO above }
begin
  resolved_uid := uid_$nil;

  name_$resolve_internal(path, path_len, dir_uid, file_uid, status);
  if status.all = status_$naming_directory_not_found_in_pathname then
    status.all := name_$not_found;
  if status.all = status_$ok then
    resolved_uid := file_uid;
end;
