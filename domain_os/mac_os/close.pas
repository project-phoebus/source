{ MAC_OS_$CLOSE - close a channel at the MAC_OS level.

  Image addresses:
    sau2  0x00E0B45C  MAC_OS_$CLOSE

  - Under the MAC_OS lock the channel's driver closes the line through
    its close entry; the port's packet-type entries naming the channel
    are removed (the last entry moved into each place), and the channel
    marked free.

  Status stored:
    the driver's close entry's status: the line was closed, or not
    status_$mac_port_op_not_implemented (16#3A0001): the driver has no
      close entry
}

procedure mac_os_$close(in channel: pinteger; out status: status_$t);
var
  i: integer;
begin
  status.all := status_$ok;
  ml_$exclusion_start(mac_os_$exclusion);

  with mac_os_$channel_table[channel] do begin
    { the driver's close entry }
    if net_io_$driver_ptr_t(driver_info)^.close_os = nil then
      status.all := status_$mac_port_op_not_implemented
    else
      mac_os_$drv_close_t(net_io_$driver_ptr_t(driver_info)^.close_os)^(
        line_number, callback_data, status);

    { the channel's packet types }
    i := 0;
    with mac_os_$port_pkt_tables[port_index] do
      while i < entry_count do
        if entries[i].channel_index = channel then begin
          entries[i] := entries[entry_count - 1];
          entry_count := entry_count - 1;
        end
        else
          i := i + 1;

    flags := flags - [mac_os_channel_in_use];
    driver_info := 0;
    callback := nil;
  end;

  ml_$exclusion_stop(mac_os_$exclusion);
end;
