{ REM_NAME_$FIND_NETWORK - look a node's entry up in a directory on the
  current naming server, locating a server when needed.

  Image addresses:
    sau2  0x00E4ADD6  REM_NAME_$FIND_NETWORK

  - REM_NAME_$GET_ENTRY's shape (rem_name/get_entry.pas) with
    REM_NAME_$GET_ENTRY_BY_NODE_ID.

  Status stored:
    rem_name_$get_entry_by_node_id's status: the entry, "name not
      found", or a failure after a locate
    locate_server's status: no server could be located
}

{ TODO(pascal) 48 frame bytes of REM_NAME_$FIND_NETWORK hold nothing

  Above net the SAU2 frame has 48 bytes that no instruction addresses,
  the size of a directory entry (rem_name_$dir_entry_t); GET_ENTRY and
  FIND_UID, the same shape, have none.  unused_48 holds them (perhaps an
  entry the original declared and never used).  Not settled. }

procedure rem_name_$find_network(in dir_uid: uid_$t;
                                 in target_node: linteger;
                                 out entry: rem_name_$dir_entry_t;
                                 out status: status_$t);
var
  unused_48: array[1..48] of char;        { the TODO above }
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

  rem_name_$get_entry_by_node_id(net, node, dir_uid, target_node, entry,
                                 status);
  if (status.all = name_$not_found)
     or else (status.all = status_$ok)
     or else located then
    return;

  { once more from a located server }
  locate_server(node, net, status);
  if status.all = status_$ok then
    rem_name_$get_entry_by_node_id(net, node, dir_uid, target_node, entry,
                                   status);
end;
