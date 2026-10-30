{ name_$resolve_internal - resolve a pathname to a UID and its directory.

  Image addresses:
    sau2  0x00E4A060  name_$resolve_internal

  - NAME_$VALIDATE classifies the path: an absolute one starts at the
    node's directory, a node-data one at the node-data directory.
  - Each component is looked up (DIR_$GET_ENTRYU): "." skipped, type 1
    descends, type 0 is not found; the last lookup's directory is
    handed back.

  Status stored:
    status_$ok: no component left
    name_$bad_pathname: a relative or network path, "..", or a type-3
      entry
    name_$not_found: an entry of type 0
    dir_$get_entryu's status: a lookup failed
}

{ TODO(pascal) 4 frame bytes of name_$resolve_internal no object
  explains

  One longword of the SAU2 frame, between current_uid and start_type,
  is never addressed.  The locals are declared in the order that puts
  each at its image offset under 8-byte alignment of the 8- and 14-byte
  objects, with the stand-in unused_24 for the gap.  A declared local
  held in a register (the entry type's value, the copies of comp_len and
  comp_start) may own it. }

procedure name_$resolve_internal(in path: univ name_$long_pname_t;
                                 path_len: pinteger;
                                 out dir_uid_ret: uid_$t;
                                 out file_uid_ret: uid_$t;
                                 out status: status_$t);
  internal;
var
  entry: dir_$old_entry_t;
  current_uid: uid_$t;
  unused_24: integer32;                   { the TODO above }
  start_type: integer;
  comp_len: pinteger;                     { also held }
  comp_start: pinteger;                   { also held }
  next_pos: pinteger;
  cursor: integer;
begin
  dir_uid_ret := uid_$nil;
  file_uid_ret := uid_$nil;

  { where the path starts }
  discard(name_$validate(path, path_len, cursor, start_type));
  case start_type of
    start_path_$relative, start_path_$network: begin
        status.all := name_$bad_pathname;
        return;
      end;
    start_path_$absolute: begin
        cursor := 2;
        current_uid := name_$get_node_uid;
      end;
    start_path_$node_data: begin
        current_uid := name_$get_node_data_uid;
        cursor := 11;
        if (path_len > 10) and then (path[11] = '/') then
          cursor := 12;
      end;
  end;

  { one component per pass }
  repeat
    name_$parse_component(path, path_len, cursor, next_pos, comp_start,
                          comp_len);
    cursor := next_pos;

    if comp_len = 0 then begin
      file_uid_ret := current_uid;
      status.all := status_$ok;
      return;
    end;

    if (comp_len = 1) and then (path[comp_start] = '.') then
      next;

    dir_uid_ret := current_uid;

    if (path[comp_start + 1] = '.') and then (comp_len = 2) and then
       (path[comp_start] = '.') then begin
      status.all := name_$bad_pathname;
      return;
    end;

    dir_$get_entryu(dir_uid_ret, path[comp_start], comp_len, entry,
                    status);
    if status.all <> status_$ok then
      return;

    case entry.entry_type of
      name_$entry_none: begin
           status.all := name_$not_found;
           return;
         end;
      name_$file: begin
        current_uid := entry.uid;
      end;
      name_$link: begin
           status.all := name_$bad_pathname;
           return;
         end;
    end;
  until false;
end;
