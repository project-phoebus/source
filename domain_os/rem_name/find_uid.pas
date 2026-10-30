{ REM_NAME_$FIND_UID - look an object's entry up by its UID on the
  current naming server, locating a server when needed.

  Image addresses:
    sau2  0x00E4AE84  REM_NAME_$FIND_UID

  - REM_NAME_$GET_ENTRY's shape (rem_name/get_entry.pas) with
    REM_NAME_$GET_ENTRY_BY_UID.
  - Without GET_ENTRY's located flag, a failure right after a locate
    locates again.

  Status stored:
    rem_name_$get_entry_by_uid's status: the entry, "name not found", or
      a failure after the second locate
    locate_server's status: no server could be located
}

procedure rem_name_$find_uid(in dir_uid: uid_$t;
                             in target_uid: uid_$t;
                             out entry: rem_name_$dir_entry_t;
                             out status: status_$t);
var
  net: integer32;
  node: integer32;
begin
  if rem_name_$last_status.all <> status_$ok then begin
    locate_server(node, net, status);
    if status.all <> status_$ok then
      return;
  end
  else begin
    node := rem_name_$curr_node;
    net := rem_name_$curr_net;
  end;

  rem_name_$get_entry_by_uid(net, node, dir_uid, target_uid, entry,
                             status);
  if (status.all = name_$not_found)
     or else (status.all = status_$ok) then
    return;

  { once more from a located server }
  locate_server(node, net, status);
  if status.all = status_$ok then
    rem_name_$get_entry_by_uid(net, node, dir_uid, target_uid, entry,
                               status);
end;
