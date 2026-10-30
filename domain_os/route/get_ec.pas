{ ROUTE_$GET_EC - an eventcount of a user routing port.

  Image addresses:
    sau2  0x00E69C2C  ROUTE_$GET_EC

  - Type 0 asks for the port's socket's eventcount, type 1 for the
    port's own, registered with EC2_$REGISTER_EC1.

  Status stored:
    ec2_$register_ec1's status: the eventcount's handle was returned, or
      not
    status_$internet_unknown_network_port: no port of the summary
    status_$route_illegal_op_for_port_type: the port is not a user port
      (type 2)
    status_$route_invalid_ec_type: another type
}

procedure route_$get_ec(in port_info: route_$short_port_t;
                        in ec_type: integer;
                        out ec_ret: ec2_$ptr_t;
                        out status_ret: status_$t);
var
  index: integer;
begin
  index := route_$find_port(port_info.port_type, port_info.socket);
  if index = -1 then begin
    status_ret.all := status_$internet_unknown_network_port;
    return;
  end;

  if route_$port[index].port_type <> route_$port_type_routing then begin
    status_ret.all := status_$route_illegal_op_for_port_type;
    return;
  end;

  with route_$port[index] do
    case ec_type of
      route_$ec_socket:
        ec_ret := ec2_$register_ec1(addr(sock_$socket_ptr[socket]^.ec),
                                    status_ret);
      route_$ec_port:
        ec_ret := ec2_$register_ec1(addr(part_34.port_ec), status_ret);
      otherwise
        status_ret.all := status_$route_invalid_ec_type;
    end;
end;
