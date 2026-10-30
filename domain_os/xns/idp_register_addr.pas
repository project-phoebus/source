{ XNS_IDP_$REGISTER_ADDR - register a host address of this node for a
  routing port.

  Image addresses:
    sau2  0x00E19002  XNS_IDP_$REGISTER_ADDR

  - An address already registered for the port is replaced; otherwise
    it is appended, unless the table (four entries) is full.

  Status stored:
    status_$ok: the address was registered
    status_$xns_too_many_addrs (16#3B001D): the table is full
}

{ TODO(pascal) 4 frame bytes of XNS_IDP_$REGISTER_ADDR no object
  explains

  The SAU2 frame holds i's slot and one longword more, the stand-in
  unused_8; the routine has no other local. }

procedure xns_idp_$register_addr(in addr: xns_$host_t; in port: integer;
                                 out status: status_$t);
var
  i: integer;
  unused_8: integer32;                    { stand-in }
begin
  status.all := status_$ok;
  for i := 0 to xns_idp_$registered_count do
    if xns_idp_$addr_port[i] = port then begin
      xns_idp_$addrs[i][0] := addr[0];
      xns_idp_$addrs[i][1] := addr[1];
      xns_idp_$addrs[i][2] := addr[2];
      return;
    end;

  if i < xns_max_addrs then begin
    xns_idp_$addrs[xns_idp_$registered_count + 1][0] := addr[0];
    xns_idp_$addrs[xns_idp_$registered_count + 1][1] := addr[1];
    xns_idp_$addrs[xns_idp_$registered_count + 1][2] := addr[2];
    xns_idp_$addr_port[xns_idp_$registered_count + 1] := port;
    xns_idp_$registered_count := xns_idp_$registered_count + 1;
  end
  else
    status.all := status_$xns_too_many_addrs;
end;
