{ MAC_OS_$PROC2_CLEANUP - close the channels an ending process owns.

  Image addresses:
    sau2  0x00E0BFDE  MAC_OS_$PROC2_CLEANUP

  - Under the MAC_OS lock each channel in use and owned by the address
    space is marked free and its socket closed.
  - The driver's close entry is called if there is one, and the
    channel's entries removed from the port's packet-type table.
  - The removal copies the entry one past the last over the removed one.

  Status stored: none.
}

{ TODO(pascal) four frame bytes of MAC_OS_$PROC2_CLEANUP hold nothing

  local_status (4), channel and i (2 each) and two `with' temporaries
  (8, a lead) make 16 of the frame's bytes; the
  stand-in unused_14 holds the other 4.  No other local would live here
  (the port and its table are reached through the channel and the
  temporary).  Not settled. }

procedure mac_os_$proc2_cleanup(as_id: integer);
var
  local_status: status_$t;
  channel: integer;
  i: integer;
  unused_14: integer32;                   { stand-in: the TODO above }
begin
  ml_$exclusion_start(mac_os_$exclusion);

  for channel := 0 to 9 do
    with mac_os_$channel_table[channel] do
      if (mac_os_channel_in_use in flags) and then (bits.owner = as_id) then
      begin
        flags := flags - [mac_os_channel_in_use];
        if socket <> mac_os_no_socket then
          sock_$close(socket);
        socket := mac_os_no_socket;
        if net_io_$driver_ptr_t(driver_info)^.close_os <> nil then
          mac_os_$drv_close_t(net_io_$driver_ptr_t(driver_info)^.close_os)^(
            line_number, callback_data, local_status);

        i := 0;
        with mac_os_$port_pkt_tables[port_index] do
          while i < entry_count do
            if entries[i].channel_index = channel then begin
              entries[i] := entries[entry_count];     { one past the last:
                                                        the original's }
              entry_count := entry_count - 1;
            end
            else
              i := i + 1;

        driver_info := 0;
        callback := nil;
      end;

  ml_$exclusion_stop(mac_os_$exclusion);
end;
