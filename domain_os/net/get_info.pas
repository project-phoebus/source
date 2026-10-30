{ NET_$GET_INFO - get information about a network.

  Image addresses:
    sau2  0x00E5A192  NET_$GET_INFO

  - Not implemented; the first four parameters are not read.

  Status stored:
    status_$network_operation_not_defined_on_hardware: always
}

procedure net_$get_info(in net_id: univ net_$opaque_t; in port: univ net_$opaque_t;
                        in param3: univ net_$opaque_t; in param4: univ net_$opaque_t;
                        out status: status_$t);
begin
  status.all := status_$network_operation_not_defined_on_hardware;
end;
