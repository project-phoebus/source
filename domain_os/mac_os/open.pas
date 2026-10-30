{ MAC_OS_$OPEN - open a channel on a port at the MAC_OS level.

  Image addresses:
    sau2  0x00E0B246  MAC_OS_$OPEN

  - Under the MAC_OS lock a free channel is found and the caller's
    packet-type ranges added to the port's table.
  - The channel gets the callback, the owner, the port, the line, the
    driver and its network type's header size, and the driver's open
    entry is called.
  - On success the record's word at 4 is saved in the channel and
    replaced by the channel number, and the driver's MTU stored at 0;
    otherwise the channel is released.
  - With all ten channels in use the search takes an eleventh slot.

  Status stored:
    the driver's open entry's status: the channel was opened, or not
    status_$mac_port_op_not_implemented (16#3A0001): no routing port,
      driver or open entry, or network type 1, 2 or above 5
    status_$mac_no_channels_available (16#3A0002): no free channel
    status_$mac_packet_type_table_full (16#3A0003): no room for the
      ranges
    status_$mac_packet_type_in_use (16#3A0005): a range overlaps one
      already in the table
}

{ TODO(pascal) the owner field's merge of PROC1_$AS_ID is unmasked

  The shifted value is or-ed into the owner field with no mask.  That is
  the form for a value whose type admits no negative values (a rule not
  settled); proc1/proc1.ins.pas
  declares proc1_$as_id `integer' ("no compare shows its sign"), and
  `dpc -o' on a scratch unit masks an integer value and not a 0..63 one.
  Either PROC1_$AS_ID's type is unsigned (a pinteger or a 0..63
  subrange; its other readers scale it as a word index, which a change
  of type must keep: tty_$i_wait, TIME_$WAIT, NET_IO_$CREATE_PORT) or
  the rule is wrong (PACCT's word counter is the open case).  The
  heading is kept. }

{ TODO(pascal) six frame bytes of MAC_OS_$OPEN hold nothing

  The six locals take 18 bytes (drv, route_port and port_table
  addressed; channel, new_count and i register-held), and the four
  `with' statements' temporaries 16 if each has a frame slot (a lead; dpc
  allocates none).  The stand-in unused_6 holds the other 6 bytes (34 + 6 =
  40).  Locals one might add for the count, the network type, a packet-type
  pointer or the channel are not seen in the code.  Not settled. }

procedure mac_os_$open(in port_num: integer;
                       in out params: mac_os_$open_params_t;
                       out status: status_$t);
label
  done;
type
  table_ptr_t = ^mac_os_$port_pkt_table_t;
var
  drv: net_io_$driver_ptr_t;
  route_port: route_$port_ptr_t;
  port_table: table_ptr_t;
  channel: pinteger;
  new_count: integer;
  i: integer;
  unused_6: array[1..6] of char;          { stand-in: the TODO above }
begin
  { the port and its driver }
  status.all := status_$ok;
  route_port := route_$portp[port_num];
  if route_port = nil then begin
    status.all := status_$mac_port_op_not_implemented;
    return;
  end;
  drv := net_io_$driver_ptr_t(route_port^.driver_info);
  if drv = nil then begin
    status.all := status_$mac_port_op_not_implemented;
    return;
  end;
  if drv^.open_os = nil then begin
    status.all := status_$mac_port_op_not_implemented;
    return;
  end;

  { a free channel }
  ml_$exclusion_start(mac_os_$exclusion);
  channel := 0;
  while mac_os_channel_in_use in mac_os_$channel_table[channel].flags do
  begin
    if channel >= mac_os_max_channels then begin
      status.all := status_$mac_no_channels_available;
      goto done;
    end;
    channel := channel + 1;
  end;

  port_table := addr(mac_os_$port_pkt_tables[port_num]);
  new_count := port_table^.entry_count + params.num_pkt_types;
  if new_count > mac_os_max_pkt_types then begin
    status.all := status_$mac_packet_type_table_full;
    goto done;
  end;

  { the caller's ranges into the port's table }
  for i := 0 to params.num_pkt_types - 1 do begin
    if mac_os_$check_range_overlap(params.pkt_types[i], port_table^.entries,
                                   port_table^.entry_count) then begin
      status.all := status_$mac_packet_type_in_use;
      goto done;
    end;
    with port_table^.entries[i + port_table^.entry_count] do begin
      range := params.pkt_types[i];
      channel_index := channel;
    end;
  end;

  { the channel }
  with mac_os_$channel_table[channel] do begin
    callback := params.callback;
    flags := flags + [mac_os_channel_in_use];
    bits.owner := proc1_$as_id;
    port_index := port_num;
    line_number := route_port^.socket;
    driver_info := integer32(drv);
    case route_port^.port_type of
      mac_os_net_type_ethernet, mac_os_net_type_3: begin
        header_size := mac_os_hdr_size_ethernet;
      end;
      mac_os_net_type_fddi: begin
        header_size := mac_os_hdr_size_fddi;
      end;
      mac_os_net_type_token_ring: begin
        header_size := mac_os_hdr_size_token_ring;
      end;
      otherwise begin
        status.all := status_$mac_port_op_not_implemented;
        goto done;
      end;
    end;
  end;

  mac_os_$drv_open_t(drv^.open_os)^(route_port^.socket, params, status);

done:
  if status.all = status_$ok then begin
    port_table^.entry_count := new_count;
    with mac_os_$channel_table[channel] do begin
      callback_data := params.channel;
      params.channel := channel;
    end;
    params.mtu := drv^.mtu;
  end
  else
    with mac_os_$channel_table[channel] do begin
      flags := flags - [mac_os_channel_in_use];
      callback := nil;
    end;
  ml_$exclusion_stop(mac_os_$exclusion);
end;
