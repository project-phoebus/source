{ MAC_OS_$PUT_INFO - store a port's version and configuration record.

  Image addresses:
    sau2  0x00E0C228  MAC_OS_$PUT_INFO

  - Under the MAC_OS lock, unless one of the port's XNS addresses is
    another port's, the 8-byte record is copied into the port's
    MAC_OS_$PORT_TABLE entry.
  - The duplicate-address exit returns with MAC_OS_$EXCLUSION held.

  Status stored:
    status_$ok: the record was stored
    status_$mac_invalid_port_version (16#3A000D): a version other than 1
    status_$mac_XXX_unknown_2 (16#3A000E): a duplicate XNS address
}

{ TODO(pascal) twelve frame bytes of MAC_OS_$PUT_INFO hold nothing

  Twelve bytes lie between other_rec (addressed) and the first of the
  two stepped pointers the compiler keeps in the frame; no instruction
  addresses them.  The stand-in unused_28 holds the place (if the
  compiler's two frame pointers are temporaries below the locals, as
  here, the stand-in is the locals' last).  Two count locals would be
  the hoisted bounds, which would take 4 bytes;
  nothing accounts for the rest.  Not settled. }

procedure mac_os_$put_info(in info: mac_os_$port_info_t;
                           in port_num: integer;
                           out status: status_$t);
type
  info_ptr_t = ^mac_os_$port_info_t;
var
  dst: info_ptr_t;
  src: info_ptr_t;
  port_rec: route_$port_ptr_t;
  other: integer;
  a: integer;                             { never formed }
  b: integer;                             { never formed }
  other_rec: route_$port_ptr_t;
  unused_28: array[1..12] of char;        { stand-in: the TODO above }
begin
  status.all := status_$ok;
  if info.version <> 1 then begin
    status.all := status_$mac_invalid_port_version;
    return;
  end;

  { no other port may have the same address }
  ml_$exclusion_start(mac_os_$exclusion);
  for other := 0 to 7 do
    if other <> port_num then begin
      port_rec := route_$portp[port_num];
      other_rec := route_$portp[other];
      for a := 0 to port_rec^.n_net_addrs - 1 do
        for b := 0 to other_rec^.n_net_addrs - 1 do
          if (port_rec^.xns_addr[a].network
              = other_rec^.xns_addr[b].network)
             and then (port_rec^.xns_addr[a].host[0]
                       = other_rec^.xns_addr[b].host[0])
             and then (port_rec^.xns_addr[a].host[1]
                       = other_rec^.xns_addr[b].host[1])
             and then (port_rec^.xns_addr[a].host[2]
                       = other_rec^.xns_addr[b].host[2])
             and then (port_rec^.xns_addr[a].socket
                       = other_rec^.xns_addr[b].socket) then begin
            status.all := status_$mac_XXX_unknown_2;
            return;                                       { the lock held }
          end;
    end;

  dst := addr(mac_os_$port_table[port_num]);
  src := addr(info);
  os_$data_copy(src^, dst^, 8);
  ml_$exclusion_stop(mac_os_$exclusion);
end;
