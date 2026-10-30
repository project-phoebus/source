{ LOCATE_SERVER - find a naming server, at most four tries until one
  answers, and forget it when it has been silent too long.

  Image addresses:
    sau2  0x00E4A420  LOCATE_SERVER

  - A server heard from is asked again (REM_NAME_$LOCATE_SERVER) within
    the timeout, and forgotten after it.
  - Until one is heard from, four attempts in all.
  - A global without `$'.

  Status stored:
    rem_name_$locate_server's status: a server was asked
    status_$naming_cant_find_name_server_helper: the server was
      forgotten (REM_NAME_$LAST_STATUS too), or four attempts were made
}

procedure locate_server(out node_ret: integer32;
                        out net_ret: integer32;
                        out status: status_$t);
begin
  if rem_name_$heard_from_server then begin
    { a server known: ask again within the timeout }
    if abs(rem_name_$time_heard_from_server - time_$clockh) >
       rem_name_$server_timeout then begin
      rem_name_$heard_from_server := false;
      rem_name_$last_status.all :=
        status_$naming_cant_find_name_server_helper;
      status.all := status_$naming_cant_find_name_server_helper;
    end
    else
      rem_name_$locate_server(node_ret, net_ret, status);
  end
  { no server yet, and four attempts made }
  else if rem_name_$retry_count > 3 then
    status.all := status_$naming_cant_find_name_server_helper
  else begin
    rem_name_$retry_count := rem_name_$retry_count + 1;
    rem_name_$locate_server(node_ret, net_ret, status);
    if status.all = status_$ok then begin
      rem_name_$heard_from_server := true;
      rem_name_$time_heard_from_server := time_$clockh;
    end;
  end;
end;
