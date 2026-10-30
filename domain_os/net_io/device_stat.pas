{ NET_IO_$DEVICE_STAT - a network port's statistics, from its driver.

  Image addresses:
    sau2  0x00E5A39C  NET_IO_$DEVICE_STAT

  - The port's driver hands back its network UID and its get_stats entry
    fills the buffer; with no port, UNKNOWN_$NETWORK_UID.  The length
    starts at 0.

  Status stored:
    the driver's get_stats status: it has the entry
    status_$ok: it has none
    status_$internet_unknown_network_port: no such port
}

procedure net_io_$device_stat(network: integer; index: integer;
                              max_len: integer; out id_ret: uid_$t;
                              stat_buf: univ_ptr;
                              out stat_len_ret: integer;
                              out status_ret: status_$t);
  options(val_param);
var
  port: route_$port_ptr_t;
  driver: net_io_$driver_ptr_t;
begin
  port := route_$find_portp(network, index);
  stat_len_ret := 0;

  if port = nil then begin
    id_ret := unknown_$network_uid;
    status_ret.all := status_$internet_unknown_network_port;
  end
  else begin
    driver := net_io_$driver_ptr_t(port^.driver_info);
    id_ret := driver^.network_uid;
    if driver^.get_stats = nil then
      status_ret.all := status_$ok
    else
      driver^.get_stats^(index, stat_buf, max_len, stat_len_ret,
                         status_ret);
  end;
end;
