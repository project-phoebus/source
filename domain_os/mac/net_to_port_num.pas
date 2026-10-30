{ MAC_$NET_TO_PORT_NUM - the port number of a network.

  Image addresses:
    sau2  0x00E0C350  MAC_$NET_TO_PORT_NUM

  - Network 0 is port 0; otherwise the routing port whose network it is,
    or -1 if none of the eight is.
  - A MAC_OS fragment (mac/README.md).

  Status stored: none.
}

procedure mac_$net_to_port_num(in net_id: integer32; out port_num: integer);
var
  i: integer;
  port: route_$port_ptr_t;
begin
  if net_id = 0 then
    port_num := 0
  else begin
    port_num := -1;
    for i := 0 to 7 do begin
      port := route_$portp[i];
      if net_id = port^.network then begin
        port_num := i;
        return;
      end;
    end;
  end;
end;
