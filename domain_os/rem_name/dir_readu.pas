{ REM_NAME_$DIR_READU - read a directory's entries from the current
  naming server, as many round trips as it takes.

  Image addresses:
    sau2  0x00E4AC2C  REM_NAME_$DIR_READU

  - Reads from the continuation's index until max_entries are filled;
    the end of a replicated root ends the read with success.
  - A failure on the very first read locates a server (LOCATE_SERVER)
    and tries again; any later failure ends the read with success.  The
    continuation is cleared whenever the read ends early.

  Status stored:
    status_$ok: the entries were read, or the read ended
    locate_server's status: no server could be located
}

procedure rem_name_$dir_readu(in dir_uid: uid_$t;
                              out entries: univ rem_name_$dir_entries_t;
                              in out continuation: rem_name_$continuation_t;
                              in max_entries: pinteger;
                              out count: pinteger;
                              out status: status_$t);
var
  net: integer32;
  node: integer32;
  entries_read: pinteger;
  progressed: boolean;
begin
  count := 0;
  if (max_entries = 0) or else (continuation.all = 0) then begin
    continuation.all := 0;
    status.all := status_$ok;
    return;
  end;

  progressed := false;
  net := rem_name_$curr_net;
  node := rem_name_$curr_node;

  while count < max_entries do begin
    rem_name_$read_dir(net, node, dir_uid, continuation.index,
                       entries[count + 1], max_entries - count,
                       entries_read, status);
    if status.all = status_$ok then begin
      progressed := true;
      continuation.index := continuation.index + entries_read;
      count := count + entries_read;
    end
    else if (status.all =
             status_$naming_cannot_find_entry_in_replicated_root)
            or else (status.all =
             status_$naming_last_entry_in_replicated_root_returned)
    then begin
      continuation.all := 0;
      count := count + entries_read;
      status.all := status_$ok;
      return;
    end
    else if not progressed and then (continuation.index = 1) then begin
      locate_server(node, net, status);
      if status.all <> status_$ok then begin
        continuation.all := 0;
        return;
      end;
      progressed := true;
    end
    else begin
      continuation.all := 0;
      status.all := status_$ok;
      return;
    end;
  end;
end;
