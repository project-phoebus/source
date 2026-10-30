{ NET_IO_$CREATE_PORT - create a network port for a driver.

  Image addresses:
    sau2  0x00E5A4A4  NET_IO_$CREATE_PORT

  - The boot device's port, or a hardware port with no boot device and
    port 0 free, becomes port 0; another takes the first free of 1..7.
    The result is the port's number, -1 on a failure.
  - A local port's socket word is its number; a user port gets a free
    ROUTE_$USER_STAT record and a socket.  The creating address space is
    recorded and the cleanup handler registered.
  - The statistics clear runs 145 times.

  Status stored:
    status_$ok: the port was created
    status_$route_illegal_op_for_port_type: the hardware port exists
    status_$net_io_max_ports_open: no free port of 1..7
    status_$net_io_max_user_ports_open: no free user statistics record
    status_$net_io_no_user_buffer_queues: no socket for the user port
}

function net_io_$create_port(ptype: integer; unit: integer;
                             driver: univ_ptr; queue_size: pinteger;
                             out status_ret: status_$t): integer;
  options(val_param);
var
  port_index: integer;
  i: integer;
  j: integer;
  stat_index: integer;
  k: integer;
begin
  net_io_$create_port := -1;
  if (ptype in [route_$port_type_local, route_$port_type_routing])
     or (route_$find_portp(ptype, unit) = nil) then
    status_ret.all := status_$ok
  else begin
    status_ret.all := status_$route_illegal_op_for_port_type;
    return;
  end;

  if ((ptype = net_io_$boot_port_type) and then (unit = net_io_$boot_unit))
     or else ((net_io_$boot_unit = net_io_$no_boot_unit)
              and then (route_$port[0].active = 0)
              and then not (ptype in [route_$port_type_local,
                                      route_$port_type_routing])) then
    port_index := 0
  else begin
    status_ret.all := status_$net_io_max_ports_open;
    for i := 1 to 7 do
      if route_$portp[i]^.active = 0 then begin
        port_index := i;
        status_ret.all := status_$ok;
        exit;
      end;
    if status_ret.all <> status_$ok then
      return;
  end;

  with route_$portp[port_index]^, part_34 do begin
    network := 0;
    port_type := ptype;
    socket := unit;
    driver_info := integer32(driver);
    long_4c := 2;
    stat_long_54 := 0;
    forward_count := 0;
    clock_50 := time_$current_clockh;

    case ptype of
      route_$port_type_local: begin
        socket := port_index;
        net_io_$port_asid[port_index] := proc1_$as_id;
        proc2_$set_cleanup(10);
      end;
      route_$port_type_routing: begin
        status_ret.all := status_$net_io_max_user_ports_open;
        for j := 1 to 4 do
          if not route_$user_stat[j].in_use then begin
            stat_index := j;
            status_ret.all := status_$ok;
            exit;
          end;

        if status_ret.all = status_$ok then begin
          queue_len := queue_size;
          if not sock_$allocate(socket, queue_size, queue_size,
                                queue_size, 16#400) then
            status_ret.all := status_$net_io_no_user_buffer_queues;
        end;

        if status_ret.all = status_$ok then begin
          sock_$socket_ptr[socket]^.flags.open := false;
          ec_$init(port_ec);
          driver_stats := addr(route_$user_stat[stat_index]);
          for k := 0 to 144 do
            driver_stats^.bytes[k] := chr(0);
          driver_stats^.in_use := true;
          net_io_$port_asid[port_index] := proc1_$as_id;
          proc2_$set_cleanup(10);
        end;
      end;
    end;

    if status_ret.all = status_$ok then begin
      active := 1;
      net_io_$create_port := port_index;
    end;
  end;
end;
