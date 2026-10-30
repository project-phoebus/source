{ MAC_OS_$INIT - set up MAC_OS's tables at boot.

  Image addresses:
    sau2  0x00E2F4FC  MAC_OS_$INIT
    sau9  0x3C435108  MAC_OS_$INIT

  - Each of the eight ports gets its MAC_OS_$PORT_TABLE record, an empty
    packet-type table, version 1 and configuration 0.
  - A port with a routing port and a driver takes the driver's MTU and
    gets one link address (the node's two-word ring address) and one XNS
    address (its network, host 08-00-1E-0n-nn-nn, socket 16#FFFF).
  - The ten channels are cleared.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure mac_os_$init;
var
  drv: net_io_$driver_ptr_t;
  route_port: route_$port_ptr_t;
  port: integer;                          { never formed }
  channel: integer;                       { never formed }
begin
  ml_$exclusion_init(mac_os_$exclusion);

  { the ports }
  for port := 0 to 7 do begin
    mac_os_$portp_table[port] := addr(mac_os_$port_table[port]);
    mac_os_$port_pkt_tables[port].entry_count := 0;
    with mac_os_$port_table[port] do begin
      version := 1;
      config := 0;
      route_port := route_$portp[port];
      if route_port <> nil then begin
        drv := net_io_$driver_ptr_t(route_port^.driver_info);
        if drv <> nil then begin
          mtu := drv^.mtu;
          mac_os_$nop;
          with route_port^, link_addr, xns_addr[0] do begin
            n_link_addrs := 1;
            n_net_addrs := 1;
            n_words := 2;
            addr[0] := rshft(node_$me, 16) & 16#F;
            addr[1] := node_$me;
            network := route_port^.network;
            host[0] := 16#800;
            host[1] := (rshft(node_$me, 16) & 16#F) ! 16#1E00;
            host[2] := addr[1];
            socket := 16#FFFF;
          end;
        end;
      end;
    end;
  end;

  { the channels }
  for channel := 0 to 9 do
    with mac_os_$channel_table[channel] do begin
      flags := flags - [mac_os_channel_promiscuous];
      flags := flags - [mac_os_channel_in_use];
      socket := mac_os_no_socket;
      line_number := 0;
      driver_info := 0;
      callback := nil;
    end;
end;
