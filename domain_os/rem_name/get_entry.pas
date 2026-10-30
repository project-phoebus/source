{ REM_NAME_$GET_ENTRY - look a name up in a directory on the current
  naming server, locating a server when needed.

  Image addresses:
    sau2  0x00E4AD18  REM_NAME_$GET_ENTRY

  - A server is located first when the last status is bad.  "Name not
    found", "invalid pathname" and success are final, and so is any
    failure from a server just located; else a server is located once
    more and asked again.

  Status stored:
    rem_name_$get_entry_by_name's status: the entry, or a final failure
    locate_server's status: no server could be located
}

procedure rem_name_$get_entry(in dir_uid: uid_$t;
                              in name: univ rem_name_$name_t;
                              in name_len: pinteger;
                              out entry: rem_name_$dir_entry_t;
                              out status: status_$t);
var
  net: integer32;
  node: integer32;
  located: boolean;
begin
  located := false;
  if rem_name_$last_status.all <> status_$ok then begin
    locate_server(node, net, status);
    if status.all <> status_$ok then
      return;
    located := true;
  end
  else begin
    node := rem_name_$curr_node;
    net := rem_name_$curr_net;
  end;

  rem_name_$get_entry_by_name(net, node, dir_uid, name, name_len, entry,
                              status);
  if (status.all = name_$not_found)
     or else (status.all = name_$bad_pathname)
     or else (status.all = status_$ok)
     or else located then
    return;

  { once more from a located server }
  locate_server(node, net, status);
  if status.all = status_$ok then
    rem_name_$get_entry_by_name(net, node, dir_uid, name, name_len, entry,
                                status);
end;
