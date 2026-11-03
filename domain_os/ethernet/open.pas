{ ethernet_open - open a channel on a unit for a set of packet types.

  Image addresses:
    sau8  0x03C86C2E  ethernet_open
    sau9  0x3C48282E  ethernet_open

  - The driver is wired and, under the unit's lock, the first user brings
    the unit on line and loads the adapter's program; a program that
    fails to load on a unit that is on line is logged (as by
    ETHERNET_$LOAD) and the open goes on.  The 82586 is configured with
    receive mode 3 if it is not yet.
  - Under the channel lock a free channel is found and the ranges
    checked and added to the table; the channel gets the system's socket
    (os) or a new one.  On failure the open is uncounted: the last user
    stops the receive process, else a configuration this open made is
    undone.

  Status stored:
    status_$ok: the channel was opened
    status_$eth_driver_version_mismatch: args.version is above 2
    status_$eth_invalid_unit_num: unit is not 0 or 1
    ethernet_start_unit's status: the unit could not be brought on line
    ethernet_download's or ethernet_execute's status: the program failed
      to load on a unit that is not on line
    ethernet_configure's status: the 82586 could not be configured
    status_$eth_no_channels: no free channel, no room in the table, or
      no socket
    status_$eth_invalid_pkt_type: a range's low is above its high
    status_$eth_pkt_type_in_use: a range meets the table's or holds the
      Domain type
    ec2_$register_ec1's status: the open's answer
}

procedure ethernet_open(os: boolean; var unit: pinteger;
                        var args: ethernet_$open_args_t;
                        out status: status_$t);
  internal;
label
  no_chan, done, finish;
var
  rec: ethernet_$load_log_t;
  err: status_$t;
  cfg_status: status_$t;
  start: integer;
  new_sock: pinteger;
  u: ethernet_$unit_ptr_t;
  ch: integer;
  i: integer;
  sock_num: pinteger;
  alloc_ok: boolean;
  locked: boolean;
  configured: boolean;
begin
  if args.version > eth_open_version then begin
    status.all := status_$eth_driver_version_mismatch;
    return;
  end;
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;

  { the unit }
  u := addr(ether_ucb[unit]);
  ethernet_wire_driver(u);
  ml_$exclusion_start(u^.lock);
  if u^.users = 0 then begin
    ethernet_start_unit(u, status);
    if status.all = status_$ok then begin
      ethernet_download(u, '/sys/ethernet8_microcode', 24, start, status);
      rec.step := eth_load_download;
      if status.all = status_$ok then begin
        ethernet_execute(u, start, status);
        rec.step := eth_load_execute;
      end;
    end;
    if status.all <> status_$ok then
      if eth_unit_online in u^.flags then begin
        err := status;
        rec.code := eth_log_load;
        rec.unit := unit;
        rec.network := ethernet_driver.network_uid;
        rec.status := err;
        log_$add(eth_log_type, rec, 18);
        with u^ do
          stats.counts[7] := stats.counts[7] + 1;
        status.all := status_$ok;
      end;
  end
  else
    status.all := status_$ok;
  u^.users := u^.users + 1;
  configured := false;
  if status.all = status_$ok then
    if not (eth_unit_cfg_3 in u^.flags) then begin
      ethernet_configure(u, true, status);
      if status.all = status_$ok then
        configured := true;
    end;
  if status.all = status_$ok then begin
    ml_$exclusion_stop(u^.lock);
    locked := false;
  end
  else begin
    with u^ do
      stats.counts[7] := stats.counts[7] + 1;
    locked := true;
    goto finish;
  end;

  { a free channel }
  ml_$exclusion_start(u^.excl_1098);
  ch := 1;
  while u^.channels[ch].open do begin
    if ch >= 10 then
      goto no_chan;
    ch := ch + 1;
  end;

  { the ranges }
  if u^.range_count + args.count > 32 then
    goto no_chan;
  for i := 1 to args.count do
    with args.ranges[i] do begin
      if low > high then begin
        status.all := status_$eth_invalid_pkt_type;
        goto done;
      end;
      if ethernet_range_overlaps(low, high, u^.ranges, u^.range_count)
         or else ((low <= eth_type_domain)
                  and then (eth_type_domain <= high)) then begin
        status.all := status_$eth_pkt_type_in_use;
        goto done;
      end;
      u^.ranges[i + u^.range_count].range := args.ranges[i];
      u^.ranges[i + u^.range_count].chan := ch;
    end;

  { the socket }
  if os then
    sock_num := eth_os_socket
  else begin
    alloc_ok := sock_$allocate_user(new_sock, 8, 8, 8, 1024);
    sock_num := new_sock;
    if not alloc_ok then begin
    no_chan:
      status.all := status_$eth_no_channels;
      goto done;
    end;
    sock_$socket_ptr[sock_num]^.flags.open := false;
  end;

  { the channel }
  with u^.channels[ch] do begin
    asid := proc1_$as_id;
    socket := sock_num;
    mcast_set := [];
    version := args.version;
    open := true;
  end;
  u^.range_count := u^.range_count + args.count;

done:
  ml_$exclusion_stop(u^.excl_1098);
finish:
  if status.all = status_$ok then begin
    args.channel := ch;
    args.ec2_handle :=
      ec2_$register_ec1(addr(sock_$socket_ptr[sock_num]^.ec), status);
  end
  else begin
    if not locked then
      ml_$exclusion_start(u^.lock);
    u^.users := u^.users - 1;
    if u^.users = 0 then
      ethernet_stop_rcv(u)
    else if configured then
      ethernet_configure(u, false, cfg_status);
    ml_$exclusion_stop(u^.lock);
    ethernet_unwire_driver;
  end;
end;
