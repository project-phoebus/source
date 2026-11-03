{ NETWORK_$ADD_REQUEST_SERVERS - start request server processes.

  Image addresses:
    sau2  0x00E71E0C  NETWORK_$ADD_REQUEST_SERVERS
    sau5  0x00E78F80  NETWORK_$ADD_REQUEST_SERVERS
    sau8  0x03C7C6C0  NETWORK_$ADD_REQUEST_SERVERS

  - As NETWORK_$ADD_PAGE_SERVERS, for the request servers, with the
    count limited to network_$max_request_servers (3, or 2 on the SAU5).
    The result is the count of request servers.

  Status stored:
    status_$ok: the servers were started
    proc1_$create_p's status: a creation failed
}

[section(procedure$, data$)]
function network_$add_request_servers(in count: integer;
                                      out status: status_$t): integer;
var
  n: integer;
begin
  status.all := status_$ok;
  n := network_$max_request_servers;
  if n > count then
    n := count;

  while n > network_$request_server_cnt do begin
    if network_$really_diskless and then
       (network_$request_server_cnt = 1) then
      exit;
    discard(proc1_$create_p(addr(network_$request_server), 16#18000009,
                            status));
    if status.all <> status_$ok then
      exit;
    network_$request_server_cnt := network_$request_server_cnt + 1;
  end;

  network_$add_request_servers := network_$request_server_cnt;
end;
