{ ROUTE_$SERVICE - apply one routing-service request to one port.

  Image addresses:
    sau2  0x00E6A030  ROUTE_$SERVICE
    sau2  0x00E69CCC  route_$init_routing (nested)
    sau2  0x00E69E40  route_$decrement_port (nested)
    sau2  0x00E69EC2  route_$close_port (nested)
    sau2  0x00E69FB2  route_$announce_net (nested)

  - Under the routing service's lock, the request's operations on the
    summary's port: close it, create or find it, change its network
    (RIP told; for port 0 the mother node and the hint file) or status.
  - RIP then sends its updates and the summary is refreshed.
  - Status 1 is "closed": the driver's start and attach entries run
    when a port leaves it, the stop entry when it enters it; a failure
    restores the old status.
  - The routing process is started for the second routing port of its
    kind (route_$init_routing, which crashes the system on a failure).
  - route_$close_port tests ROUTE_$SERVICE's old_status, which the close
    path does not write.

  Status stored:
    status_$ok: the request was done
    status_$internet_unknown_network_port: no port of the summary
    status_$internet_illegal_port_type: a close of a port neither local
      nor routing
    status_$route_illegal_op_for_port_type: a user-port request for a
      port not of the routing type
    status_$route_create_flag_required: a user-port request without the
      create member
    status_$route_queue_length_too_large: a queue length above 32
    net_io_$create_port's status: the port could not be created
    status_$route_service_type_bad: the new status is not 1..5
    status_$route_no_routing_zero_network: routing at a port without a
      network
    the driver's start, attach or stop entry's status: a failure (the
      old status restored)
    status_$internet_network_port_not_open: routing with no RIP IDP
      channel
}

{ TODO(pascal) 8 frame bytes of ROUTE_$SERVICE no object explains

  With the locals in the order below, the `with' temporary and the
  8-byte alignment, the frame comes to 0x74 bytes; 8 bytes (the stand-in
  unused_78) are addressed by no instruction.  A second `with' temporary
  would account for 4 of them.  (dpc gives 0x78: it gives a `with' over
  another unit's element at a constant index no temporary.) }

{ TODO(pascal) 8 frame bytes of route_$init_routing no object explains

  The link's slot, sock, socket and i come to 12 bytes; 8 more (the
  stand-ins unused_10 and unused_14) are addressed by no instruction.
  Two more locals one might expect (an eventcount value, a result) are
  values in a register the image never stores. }
procedure route_$service(in operation: route_$service_ops_t;
                         in out port_info: route_$short_port_t;
                         out status_ret: status_$t);
type
  route_$attach_proc_t = ^procedure(var socket: pinteger;
                                    in service_rec: univ integer32;
                                    request: integer;
                                    out attach_out: integer32;
                                    out status_ret: status_$t);
                         options(val_param);
var
  port_index: integer;
  source: route_$xns_addr_t;
  short_port: route_$short_port_t;
  port: route_$port_ptr_t;
  idp_status: status_$t;
  rip_status: status_$t;
  network: integer32;
  driver: univ_ptr;
  attach_out: integer32;
  old_status: integer;
  check_status: integer;
  idp_port: integer;
  queue_length: pinteger;
  i: integer;
  drv: net_io_$driver_ptr_t;
  unused_78: array[1..8] of char;         { stand-in: the TODO above }

  { route_$init_routing: the routing process's start, when the port is
    the second routing port of its kind. }
  procedure route_$init_routing(port_index: integer;
                                is_std_port: boolean);
  var
    sock: sock_$sock_ptr_t;
    socket: pinteger;
    i: integer;
    unused_10: integer32;                 { stand-in: the TODO above }
    unused_14: integer32;                 { stand-in }
  begin
    if is_std_port then begin
      route_$std_n_routing_ports := route_$std_n_routing_ports + 1;
      if (route_$std_n_routing_ports <> 2)
         or else (route_$n_routing_ports >= 2) then
        return;
    end else begin
      route_$n_routing_ports := route_$n_routing_ports + 1;
      if (route_$n_routing_ports <> 2)
         or else (route_$std_n_routing_ports >= 2) then
        return;
    end;

    for i := 0 to 128 do
      route_$q_depth[i] := 0;
    ec_$init(route_$control_ec);
    route_$control_ecval := ec_$read(route_$control_ec) + 1;

    { the parent's status }
    route_$pid := proc1_$create_p(addr(route_$process), 16#1000000C,
                                  status_ret);
    if status_ret.all <> status_$ok then begin
      crash_system(status_ret);
      return;
    end;

    route_$wire_routing_area;
    route_$netbuf_alloc := 64;
    if not sock_$allocate(socket, route_$netbuf_alloc,
                          route_$netbuf_alloc, route_$netbuf_alloc,
                          1024) then
      crash_system(status_$route_cant_create_thru_queue);

    sock := sock_$socket_ptr[socket];
    sock^.flags.open := false;
    route_$sock_ecval := ec_$read(sock^.ec) + 1;
    route_$sock := socket;
    route_$start_time := time_$current_clockh;

    route_$q_oflo := 0;
    route_$too_far := 0;
    route_$misroute := 0;
    route_$pkts_routed := 0;
    route_$dlen_err := 0;
    route_$std_too_far := 0;
    route_$std_misroute := 0;
    route_$std_pkts_routed := 0;
    route_$std_dlen_err := 0;
    ec_$advance(route_$control_ec);
  end;

  { route_$decrement_port: a port leaves the routing of its
    kind. }
  procedure route_$decrement_port(delete_flag: boolean;
                                  port_index: integer;
                                  port_type_flag: boolean);
  begin
    rip_$port_close(port_index, port_type_flag, delete_flag);
    if port_type_flag then begin
      route_$std_n_routing_ports := route_$std_n_routing_ports - 1;
      if route_$std_n_routing_ports = 1 then
        rip_$halt_router(true);
    end else begin
      route_$n_routing_ports := route_$n_routing_ports - 1;
      if route_$n_routing_ports = 1 then
        rip_$halt_router(false);
    end;

    if route_$routing and then (route_$n_routing_ports < 2)
       and then (route_$std_n_routing_ports < 2) then
      ec_$advance(route_$control_ec);
  end;

  { route_$close_port: the close operation, on the parent's
    summary and status. }
  procedure route_$close_port;
  var
    source: rip_$dest_addr_t;
    port_index: integer;
    port: route_$port_ptr_t;
  begin
    port_index := route_$find_port(port_info.port_type, port_info.socket);
    if port_index = -1 then begin
      status_ret.all := status_$internet_unknown_network_port;
      return;
    end;

    if not (port_info.port_type
            in [route_$port_type_local, route_$port_type_routing]) then begin
      status_ret.all := status_$internet_illegal_port_type;
      return;
    end;

    { old_status is the parent's, which the close operation's path has
      not written }
    port := addr(route_$port[port_index]);
    if old_status in [3, 5] then
      route_$decrement_port(true, port_index, false);

    route_$short_port(port^, short_port);
    source.network := port^.network;
    source.host_node := 0;
    rip_$update_d(port^.network, source, 16, short_port, false,
                  status_ret);

    if port^.port_type = route_$port_type_routing then begin
      sock_$close(port^.socket);
      route_$n_user_ports := route_$n_user_ports - 1;
      route_$cleanup_wired;
      port^.part_34.driver_stats^.in_use := false;
    end;
    port^.active := 0;
  end;

  { route_$announce_net: tell the mother node a diskless
    node's network. }
  procedure route_$announce_net(network: integer32);
  var
    ctl: rip_$template_t;
    status: status_$t;
    timeout: pinteger;
    retry: integer;
  begin
    if network_$diskless then begin
      ctl := rip_$bcast_control;
      ctl.flags := ctl.flags - [7];
      pkt_$send_internet(network, network_$mother_node, 8,
                         route_$port[0].network, node_$me, 8, ctl,
                         pkt_$next_id, route_$announce_template, 2, 0, 0,
                         retry, timeout, status);
    end;
  end;

begin
  status_ret.all := status_$ok;
  ml_$exclusion_start(route_$service_mutex);

  if service_op_close_port in operation then begin
    route_$close_port;
    ml_$exclusion_stop(route_$service_mutex);
    return;
  end;

  if service_op_user_port in operation then begin
    if port_info.port_type <> route_$port_type_routing then
      status_ret.all := status_$route_illegal_op_for_port_type
    else if not (service_op_create_port in operation) then
      status_ret.all := status_$route_create_flag_required
    else if port_info.queue_length > 32 then
      status_ret.all := status_$route_queue_length_too_large;
    if status_ret.all <> status_$ok then begin
      ml_$exclusion_stop(route_$service_mutex);
      return;
    end;
  end;

  with route_$port[0] do
    if active in [2..5] then begin
      route_$short_port(route_$port[0], short_port);
      xns_addr[0].network := network;
      source.network := network;
      for i := 0 to 2 do
        source.host[i] := 0;
      rip_$update_d(network, source, 0, short_port, false, status_ret);
      rip_$update_d(network, source, 0, short_port, true, status_ret);
    end;

  if service_op_create_port in operation then begin
    if service_op_user_port in operation then
      queue_length := port_info.queue_length
    else
      queue_length := 10;
    if port_info.port_type = route_$port_type_local then
      driver := addr(net_io_$nil_driver)
    else
      driver := addr(net_io_$user_driver);
    port_index := net_io_$create_port(port_info.port_type, 0, driver,
                                      queue_length, status_ret);
    if status_ret.all <> status_$ok then begin
      ml_$exclusion_stop(route_$service_mutex);
      return;
    end;
    if port_info.port_type = route_$port_type_routing then begin
      route_$n_user_ports := route_$n_user_ports + 1;
      route_$wire_routing_area;
    end;
  end else begin
    port_index := route_$find_port(port_info.port_type, port_info.socket);
    if port_index = -1 then begin
      ml_$exclusion_stop(route_$service_mutex);
      status_ret.all := status_$internet_unknown_network_port;
      return;
    end;
  end;

  if (service_op_set_status in operation)
     and then not (port_info.status in [1..5]) then begin
    ml_$exclusion_stop(route_$service_mutex);
    status_ret.all := status_$route_service_type_bad;
    return;
  end;

  port := addr(route_$port[port_index]);
  if service_op_set_network in operation then
    network := port_info.network
  else
    network := port^.network;
  if network = 0 then begin
    if service_op_set_status in operation then
      check_status := port_info.status
    else
      check_status := port^.active;
    if check_status in [3..5] then begin
      status_ret.all := status_$route_no_routing_zero_network;
      route_$short_port(port^, port_info);
      ml_$exclusion_stop(route_$service_mutex);
      return;
    end;
  end;

  if (service_op_set_network in operation)
     and then (port^.network <> port_info.network) then begin
    if port^.network <> 0 then begin
      route_$short_port(port^, short_port);
      source.network := port^.network;
      for i := 0 to 2 do
        source.host[i] := 0;
      rip_$update_d(port^.network, source, 16, short_port, false,
                    rip_status);
      rip_$update_d(port^.network, source, 16, short_port, true,
                    rip_status);
    end;
    if port_index = 0 then begin
      route_$announce_net(port_info.network);
      hint_$add_net(port_info.network);
    end;
    port^.network := port_info.network;
    port^.xns_addr[0].network := port^.network;
    if port_info.network <> 0 then begin
      route_$short_port(port^, short_port);
      source.network := port_info.network;
      for i := 0 to 2 do
        source.host[i] := 0;
      rip_$update_d(port_info.network, source, 0, short_port, false,
                    rip_status);
      rip_$update_d(port_info.network, source, 0, short_port, true,
                    rip_status);
    end;
  end;

  if (service_op_set_status in operation)
     and then (port^.active <> port_info.status) then begin
    old_status := port^.active;

    if (old_status in [4, 5]) and then (port_info.status in [1..3]) then
      route_$decrement_port(false, port_index, true);
    if (old_status in [3, 5]) and then (port_info.status in [1, 2, 4]) then
      route_$decrement_port(false, port_index, false);

    if old_status = 1 then begin
      drv := net_io_$driver_ptr_t(port^.driver_info);
      if drv^.start <> nil then
        drv^.start^(port^.socket, status_ret);
      if (status_ret.all = status_$ok) and then (drv^.detach <> nil) then
        route_$attach_proc_t(drv^.detach)^(port^.socket, 0, 0, attach_out,
                                           status_ret);
    end;

    port^.active := port_info.status;
    if (old_status = 1) and then (status_ret.all = status_$ok) then begin
      if rip_$std_idp_channel <> 16#FFFF then begin
        idp_port := port_index;
        xns_idp_$os_add_port(rip_$std_idp_channel, idp_port, idp_status);
      end;
      if app_$std_idp_channel <> 16#FFFF then begin
        idp_port := port_index;
        xns_idp_$os_add_port(app_$std_idp_channel, idp_port, idp_status);
      end;
    end;

    if (status_ret.all = status_$ok) and then (old_status in [1..3])
       and then (port_info.status in [4, 5]) then
      if rip_$std_idp_channel <> 16#FFFF then
        route_$init_routing(port_index, true)
      else
        status_ret.all := status_$internet_network_port_not_open;
    if (status_ret.all = status_$ok) and then (old_status in [1, 2, 4])
       and then (port_info.status in [3, 5]) then
      route_$init_routing(port_index, false);

    if status_ret.all = status_$ok then begin
      if port^.active = 1 then begin
        drv := net_io_$driver_ptr_t(port^.driver_info);
        if drv^.stop <> nil then
          net_io_$start_proc_t(drv^.stop)^(port^.socket, status_ret);
        if rip_$std_idp_channel <> 16#FFFF then begin
          idp_port := port_index;
          xns_idp_$os_delete_port(rip_$std_idp_channel, idp_port,
                                  idp_status);
        end;
        if app_$std_idp_channel <> 16#FFFF then begin
          idp_port := port_index;
          xns_idp_$os_delete_port(app_$std_idp_channel, idp_port,
                                  idp_status);
        end;
      end;
    end else
      port^.active := old_status;
  end;

  ml_$exclusion_stop(route_$service_mutex);
  rip_$send_updates(false);
  rip_$send_updates(true);
  route_$short_port(route_$port[port_index], port_info);
end;
