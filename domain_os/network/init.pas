{ NETWORK_$INIT - start the network layer.

  Image addresses:
    sau2  0x00E2F684  NETWORK_$INIT
    sau8  0x03C3234C  NETWORK_$INIT

  - The network table is cleared, the allowed services set (paging,
    file, active and reserved_4 when port 0 is active, none otherwise)
    with a remote pool of 0.
  - PKT_, NETBUF_, MSG_, NET_IO_, RIP_, MAC_OS_ and XNS_IDP_ are started.
  - The module's header page is taken and mapped, the ring controller's
    DCTE found, and one page server started; a failure of the page or
    the server crashes the system.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure network_$init;
var
  ppn: integer32;
  value: network_$service_t;
  status: status_$t;
  i: integer;
begin
  { the network table }
  for i := 1 to 64 do begin
    network_$net_table[i].refcount := 0;
    network_$net_table[i].net_id := 0;
  end;

  { PKT_, the services, NETBUF_, MSG_ }
  pkt_$init;
  if route_$port[0].active = 0 then
    value.service := []
  else
    value.service := [network_service_paging, network_service_file,
                      network_service_active, network_service_reserved_4];
  network_$set_service(network_op_set_value, value, status);
  value.remote_pool := 0;
  network_$set_service(network_op_set_remote_pool, value, status);
  netbuf_$init;
  msg_$init;

  { the header page }
  wp_$calloc(ppn, status);
  network_$hdr_page_pa := lshft(ppn, 10);
  netbuf_$getva(network_$hdr_page_pa, network_$hdr_page, status);
  if status.all <> status_$ok then
    crash_system(status);

  { the protocol layers and the ring's DCTE }
  net_io_$init;
  rip_$init;
  mac_os_$init;
  xns_idp_$init;
  network_$ring_dcte := io_$get_dcte(2, 0, status);
  if status.all <> status_$ok then
    network_$ring_dcte := nil;

  { the page servers }
  network_$page_wait[1] := 1;
  network_$page_wait[2] := 0;
  network_$page_wait[3] := netlog_$ec.value + 1;
  network_$page_wait[4] := time_$clockh_ec.value + 4;
  discard(network_$add_page_servers(1, status));
  if status.all <> status_$ok then
    crash_system(status);

  { the request server's wait values }
  network_$rqst_wait[1] := 1;
  network_$rqst_wait[2] := 1;
  network_$rqst_wait[3] := 1;
  network_$rqst_wait[4] := time_$clockh_ec.value + 60;
  network_$age_ticks := 0;
end;
