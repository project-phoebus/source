{ NETWORK_$ADD_PAGE_SERVERS - start page server processes.

  Image addresses:
    sau2  0x00E71DA4  NETWORK_$ADD_PAGE_SERVERS
    sau6  0x78080230  NETWORK_$ADD_PAGE_SERVERS
    sau7  0x3C4883DC  NETWORK_$ADD_PAGE_SERVERS
    sau8  0x03C7C658  NETWORK_$ADD_PAGE_SERVERS

  - Page servers are started until there are count of them, a creation
    fails, or, on a really diskless node, there is one.  The result is
    the count of page servers.

  Status stored:
    status_$ok: the servers were started
    proc1_$create_p's status: a creation failed
}

[section(procedure$, data$)]
function network_$add_page_servers(in count: integer;
                                   out status: status_$t): integer;
begin
  status.all := status_$ok;

  while count > network_$page_server_cnt do begin
    if network_$really_diskless and then (network_$page_server_cnt = 1) then
      exit;
    discard(proc1_$create_p(addr(network_$page_server), 16#10000008,
                            status));
    if status.all <> status_$ok then
      exit;
    network_$page_server_cnt := network_$page_server_cnt + 1;
  end;

  network_$add_page_servers := network_$page_server_cnt;
end;
