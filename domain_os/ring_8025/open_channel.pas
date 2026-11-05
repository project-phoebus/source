{ ring_8025_open_channel - open a channel on a unit for a set of frame
  types.

  Image addresses:
    sau7  0x3C4984F6  ring_8025_open_channel
    sau8  0x03C8BAE6  ring_8025_open_channel
    sau9  0x3C4876EA  ring_8025_open_channel

  - The driver is wired and, under the unit's lock, the first user
    brings the unit on line (ring_8025_start_unit); each success counts
    a user.
  - Under the channel lock a free channel is found and the ranges
    checked and added to the table; the channel gets the system's socket
    (os) or a new one, and its LLC classes are added to the unit's.  On
    failure the open is uncounted: the last user stops the receive
    process.  The driver is unwired after any failure but the wiring's.

  Status stored:
    status_$ok: the channel was opened
    status_$r8025_driver_version_mismatch: args.version is above 2
    status_$r8025_invalid_unit_num: unit is not 0 or 1
    ring_8025_wire_driver's status: the driver could not be wired
    ring_8025_start_unit's status: the unit could not be brought on line
    status_$r8025_no_channels: no free channel, no room in the table, or
      no socket
    status_$r8025_invalid_frame_type: a range's low is above its high
    status_$r8025_frame_type_in_use: a range meets the table's or holds
      the Domain type
    ec2_$register_ec1's status: the open's answer
}

procedure ring_8025_open_channel(os: boolean; var unit: pinteger;
                                 var args: ring_8025_$open_args_t;
                                 out status: status_$t);
  internal;
label
  no_chan, done;
var
  lo: ring_8025_$ftype_t;
  hi: ring_8025_$ftype_t;
  new_sock: pinteger;
  u: ring_8025_$unit_ptr_t;
  ch: integer;
  i: integer;
  sock_num: pinteger;
  alloc_ok: boolean;
begin
  if args.version > r8025_open_version then begin
    status.all := status_$r8025_driver_version_mismatch;
    return;
  end;
  if unit > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;

  { the unit }
  u := addr(ring8025_ucb[unit]);
  ring_8025_wire_driver(u, status);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(u^.lock);
  if u^.users = 0 then begin
    ring_8025_start_unit(u, status);
    if status.all = status_$ok then
      u^.users := 1;
  end
  else begin
    u^.users := u^.users + 1;
    status.all := status_$ok;
  end;
  ml_$exclusion_stop(u^.lock);

  if status.all = status_$ok then begin
    { a free channel }
    ml_$exclusion_start(u^.chan_lock);
    ch := 1;
    while u^.channels[ch].open do begin
      if ch >= r8025_max_chan then
        goto no_chan;
      ch := ch + 1;
    end;

    { the ranges }
    if u^.range_count + args.count > 32 then begin
      status.all := status_$r8025_no_channels;
      goto done;
    end;
    for i := 1 to args.count do
      with args.ranges[i] do begin
        lo.all := low;
        lo.zero := 0;
        hi.all := high;
        hi.zero := 0;
        if lo.all > hi.all then begin
          status.all := status_$r8025_invalid_frame_type;
          goto done;
        end;
        if ring_8025_range_overlaps(lo.all, hi.all, u^.ranges,
                                    u^.range_count)
           or else ((lo.all <= r8025_type_domain)
                    and then (r8025_type_domain <= hi.all)) then begin
          status.all := status_$r8025_frame_type_in_use;
          goto done;
        end;
        u^.ranges[i + u^.range_count].low := lo.all;
        u^.ranges[i + u^.range_count].high := hi.all;
        u^.ranges[i + u^.range_count].chan := ch;
      end;

    { the socket }
    if os then
      sock_num := r8025_os_socket
    else begin
      alloc_ok := sock_$allocate_user(new_sock, 8, 8, 8, 3552);
      sock_num := new_sock;
      if not alloc_ok then begin
      no_chan:
        status.all := status_$r8025_no_channels;
        goto done;
      end;
      sock_$socket_ptr[sock_num]^.flags.open := false;
    end;

    { the channel }
    with u^.channels[ch] do begin
      asid := proc1_$as_id;
      socket := sock_num;
      version := args.version;
      open := true;
      llc_class := args.llc_class;
      strip_rif := args.strip_rif <> 0;
    end;
    u^.range_count := u^.range_count + args.count;
    u^.llc_class := u^.llc_class ! args.llc_class;

  done:
    ml_$exclusion_stop(u^.chan_lock);
    if status.all = status_$ok then begin
      args.channel := ch;
      args.ec2_handle :=
        ec2_$register_ec1(addr(sock_$socket_ptr[sock_num]^.ec), status);
    end
    else begin
      ml_$exclusion_start(u^.lock);
      u^.users := u^.users - 1;
      if u^.users = 0 then
        ring_8025_stop_rcv(u);
      ml_$exclusion_stop(u^.lock);
    end;
  end;
  if status.all <> status_$ok then
    ring_8025_unwire_driver;
end;
