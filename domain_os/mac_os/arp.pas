{ MAC_OS_$ARP - the link-level address for a next hop on a port.

  Image addresses:
    sau2  0x00E0C0CE  MAC_OS_$ARP

  - A host of all ones is a broadcast: the flag is set and the address
    is the network type's broadcast (two words, unset, for types 0 and
    3; three words of all ones for 4 and 5).
  - Otherwise, for types 0 and 3, only an Apollo host resolves, to its
    node number; type 5 maps such a host to 16#5000, 16#78nn and the
    third word, other hosts' words copied; type 4 copies the words.

  Status stored:
    status_$ok: the address was found
    status_$mac_port_op_not_implemented (16#3A0001): no routing port,
      or another network type
    status_$mac_arp_address_not_found (16#3A0013): a type 0 or 3 host
      that is not an Apollo one
}

procedure mac_os_$arp(in nexthop: rip_$nexthop_t; port_num: integer;
                      out link_addr: mac_os_$link_addr_t;
                      out is_broadcast: boolean;
                      out status: status_$t);
  options(val_param);
var
  route_port: route_$port_ptr_t;
  i: integer;
begin
  status.all := status_$ok;
  route_port := route_$portp[port_num];
  if route_port = nil then begin
    status.all := status_$mac_port_op_not_implemented;
    return;
  end;

  is_broadcast := false;
  if (nexthop.host[2] = 16#FFFF) and then (nexthop.host[0] = 16#FFFF)
     and then (nexthop.host[1] = 16#FFFF) then begin
    { a broadcast }
    is_broadcast := true;
    case route_port^.port_type of
      mac_os_net_type_ethernet, mac_os_net_type_3: begin
        link_addr.n_words := 2;
      end;
      mac_os_net_type_token_ring, mac_os_net_type_fddi: begin
        link_addr.n_words := 3;
        for i := 0 to 2 do
          link_addr.addr[i] := -1;
      end;
      otherwise begin
        status.all := status_$mac_port_op_not_implemented;
      end;
    end;
  end
  else
    case route_port^.port_type of
      mac_os_net_type_ethernet, mac_os_net_type_3: begin
        if (nexthop.host[0] = mac_os_ethertype_ip)
           and then ((nexthop.host[1] & 16#FF00) = 16#1E00) then begin
          link_addr.n_words := 2;
          link_addr.addr[0] := nexthop.host[1] & 16#F;
          link_addr.addr[1] := nexthop.host[2];
        end
        else
          status.all := status_$mac_arp_address_not_found;
      end;
      mac_os_net_type_fddi: begin
        link_addr.n_words := 3;
        if (nexthop.host[0] = mac_os_ethertype_ip)
           and then ((nexthop.host[1] & 16#FF00) = 16#1E00) then begin
          link_addr.addr[0] := 16#5000;
          link_addr.addr[1] := (nexthop.host[1] & 16#FF) ! 16#7800;
          link_addr.addr[2] := nexthop.host[2];
        end
        else
          for i := 0 to 2 do
            link_addr.addr[i] := nexthop.host[i];
      end;
      mac_os_net_type_token_ring: begin
        link_addr.n_words := 3;
        for i := 0 to 2 do
          link_addr.addr[i] := nexthop.host[i];
      end;
      otherwise begin
        status.all := status_$mac_port_op_not_implemented;
      end;
    end;
end;
