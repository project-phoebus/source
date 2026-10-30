{ NETWORK_$SET_SERVICE - change the node's allowed network services.

  Image addresses:
    sau2  0x00E0F45E  NETWORK_$SET_SERVICE

  - Under the module's spin lock: operation 0 adds the value's services,
    1 removes them, 2 sets them; 3 sets the remote pool's size
    (MMAP_$REMOTE_POOL).
  - After 0..2 the routing service is added when the node routes or a
    user socket is open, and the services handed to port 0's driver
    while port 0 has no type yet.

  Status stored:
    status_$ok: the operation was applied
    status_$network_request_denied_by_local_node: 1 or 2 would take
      paging or the network away from a diskless node
    status_$network_unknown_request_type: an operation above 3
}

{ TODO(pascal) NETWORK_$SET_SERVICE's frame order against dpc's

  The image: rec -0x88 (0x88 bytes), drv_status -0x90, new_service
  -0x94, the value's copy -0x98, out4 -0x9A, token -0x9C, frame 0xA0.
  dpc puts the value's copy at the top (-0x4) and packs the rest after it:
  rec -0x8C, drv_status -0x90, new_service -0x92, out4 -0x94, token -0x96,
  frame 0x9C.  The image's copy among the locals, and the 4 bytes at -0x8C
  and 2 at -0x92, are not explained. }

procedure network_$set_service(in op: integer; value: network_$service_t;
                               out status: status_$t);
var
  rec: network_$service_rec_t;
  drv_status: status_$t;
  new_service: network_$service_set_t;
  out4: integer;
  token: pinteger;
  ext: pinteger;
  drv: integer32;
begin
  token := ml_$spin_lock(network_$lock);

  case op of
    network_op_or_bits: begin
      network_$allowed_service.service :=
        network_$allowed_service.service + value.service;
    end;
    network_op_and_not_bits: begin
      new_service := network_$allowed_service.service - value.service;
      if network_$diskless and then
         (([network_service_paging, network_service_active] -
           new_service) <> []) then begin
        ml_$spin_unlock(network_$lock, token);
        status.all := status_$network_request_denied_by_local_node;
        return;
      end;
      network_$allowed_service.service := new_service;
    end;
    network_op_set_value: begin
      new_service := value.service;
      if network_$diskless and then
         (([network_service_paging, network_service_active] -
           new_service) <> []) then begin
        ml_$spin_unlock(network_$lock, token);
        status.all := status_$network_request_denied_by_local_node;
        return;
      end;
      network_$allowed_service.service := new_service;
    end;
    network_op_set_remote_pool: begin
      ml_$spin_unlock(network_$lock, token);
      network_$allowed_service.remote_pool :=
        mmap_$remote_pool(value.remote_pool);
      status.all := status_$ok;
      return;
    end;
    otherwise begin
      ml_$spin_unlock(network_$lock, token);
      status.all := status_$network_unknown_request_type;
      return;
    end;
  end;

  { routing goes with any service on a router }
  if ((route_$n_routing_ports > 1) or network_$user_sock_open) and then
     (network_$allowed_service.service <> []) then
    network_$allowed_service.service :=
      network_$allowed_service.service + [network_service_routing];
  ml_$spin_unlock(network_$lock, token);
  status.all := status_$ok;

  { tell port 0's driver }
  if route_$port[0].port_type = route_$port_type_ring then begin
    ext := 0;
    if network_service_active in network_$allowed_service.service then begin
      ext := 16#0B;
      if network_service_paging in network_$allowed_service.service then
        ext := 16#2B;
      if network_service_file in network_$allowed_service.service then
        ext := ext ! 16#10;
      if network_service_routing in network_$allowed_service.service then
        ext := ext ! 4;
      if network_service_reserved_4 in network_$allowed_service.service then
        ext := ext ! 16#80;
    end;
    rec.w_00 := 0;
    rec.ext_service := ext;
    drv := route_$port[0].driver_info;
    network_$service_proc_t(net_io_$driver_ptr_t(drv)^.ioctl)^(
      route_$port[0].socket, rec, 136, out4, drv_status);
  end;
end;
