{ XNS_IDP_$GET_PORT_INFO - a port's information (not implemented).

  Image addresses:
    sau2  0x00E18FB8  XNS_IDP_$GET_PORT_INFO

  Status stored:
    status_$mac_port_op_not_implemented: always
}

procedure xns_idp_$get_port_info(in channel: pinteger;
                                 var port_info: univ integer32;
                                 out status: status_$t);
begin
  status.all := status_$mac_port_op_not_implemented;
end;
