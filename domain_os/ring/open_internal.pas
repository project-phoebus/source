{ ring_$open_internal - open a channel on a unit for a set of packet types.

  Image addresses:
    sau2  0x00E76B7C  ring_$open_internal (module-local)
    sau8  0x03C83456  ring_$open_internal (module-local)

  - The driver is wired; under the transmit lock the first open starts
    the unit's receive process, and a unit without bit 0 in its mask
    gets 16#81 or-ed in.
  - Under the channel lock a free channel is found and the ranges
    checked and added to the table; the channel gets the system's
    socket (is_os) or a new one.  On failure the open is uncounted.
  - The unit is tested twice, before and after the version; the SAU2
    image keeps both tests.

  Status stored:
    status_$ok: the channel was opened
    status_$ring_invalid_unit_num: unit is above 1
    status_$ring_driver_version_mismatch: args.version is above 1
    ring_$do_start's status: the receive process could not be started
    status_$ring_no_channels: no free channel, no room in the table, or
      no socket
    status_$ring_invalid_svc_packet_type: a range's low is above its high
    status_$ring_pkt_type_in_use: a range meets the table's
    ec2_$register_ec1's status: the open's answer
}

procedure ring_$open_internal(is_os: boolean; var unit: pinteger;
                              var args: ring_$open_args_t;
                              out status: status_$t);
  internal;
label
  no_chan, done;
var
  new_sock: pinteger;
  mask: pinteger;
  u: ring_$unit_ptr_t;
  ch: pinteger;
  i: integer;
  sock_num: pinteger;
  alloc_ok: boolean;
begin
  if unit > 1 then begin
    status.all := status_$ring_invalid_unit_num;
    return;
  end;
  if args.version > 1 then begin
    status.all := status_$ring_driver_version_mismatch;
    return;
  end;
  if unit > 1 then begin
    status.all := status_$ring_invalid_unit_num;
    return;
  end;

  { the unit }
  u := addr(ring_$ctl[unit]);
  ring_$wire_driver;
  ml_$exclusion_start(u^.tx_exclusion);
  if u^.open_count = 0 then begin
    if not (ring_unit_started in u^.state_flags) then
      ring_$do_start(unit, u^, status)
    else
      status.all := 0;
    u^.open_count := 1;
  end
  else begin
    status.all := 0;
    u^.open_count := u^.open_count + 1;
  end;
  if not odd(u^.tmask) then begin
    mask := u^.tmask ! 16#81;
    ring_$set_hw_mask(unit, mask);
  end;
  ml_$exclusion_stop(u^.tx_exclusion);
  if status.all <> 0 then
    return;

  { a free channel }
  ml_$exclusion_start(u^.rx_exclusion);
  ch := 1;
  while u^.channels[ch].flags do begin
    if ch >= 10 then
      goto no_chan;
    ch := ch + 1;
  end;

  { the ranges }
  if u^.pkt_type_cnt + args.count > 32 then begin
    status.all := status_$ring_no_channels;
    goto done;
  end;
  for i := 1 to args.count do
    with args.types[i] do begin
      if low > high then begin
        status.all := status_$ring_invalid_svc_packet_type;
        goto done;
      end;
      if ring_$pkt_type_overlaps(low, high, u^.pkt_types,
                                 u^.pkt_type_cnt) then begin
        status.all := status_$ring_pkt_type_in_use;
        goto done;
      end;
      u^.pkt_types[i + u^.pkt_type_cnt].entry.range := args.types[i];
      u^.pkt_types[i + u^.pkt_type_cnt].entry.channel := ch;
    end;

  { the socket }
  if is_os then
    sock_num := ring_os_socket
  else begin
    alloc_ok := sock_$allocate_user(new_sock, 8, 8, 8, 16#400);
    sock_num := new_sock;
    if not alloc_ok then begin
    no_chan:
      status.all := status_$ring_no_channels;
      goto done;
    end;
    sock_$socket_ptr[sock_num]^.flags.open := false;
  end;

  { the channel }
  with u^.channels[ch] do begin
    asid := proc1_$as_id;
    socket_id := sock_num;
    open_version := args.version;
    flags := true;
  end;
  u^.pkt_type_cnt := u^.pkt_type_cnt + args.count;

done:
  ml_$exclusion_stop(u^.rx_exclusion);
  if status.all = 0 then begin
    args.channel := ch;
    args.ec2_handle := ec2_$register_ec1(addr(sock_$socket_ptr[sock_num]^.ec),
                                         status);
  end
  else begin
    ml_$exclusion_start(u^.tx_exclusion);
    u^.open_count := u^.open_count - 1;
    ml_$exclusion_stop(u^.tx_exclusion);
  end;
end;
