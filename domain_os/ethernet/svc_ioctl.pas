{ ETHERNET_$SVC_IOCTL - a user channel's control request.

  Image addresses:
    sau8  0x03C87846  set_station (nested)
    sau9  0x3C483446  set_station (nested)
    sau8  0x03C878A6  ETHERNET_$SVC_IOCTL
    sau9  0x3C4834A6  ETHERNET_$SVC_IOCTL

  - The driver record's svc_ioctl entry.  The requests (eth_ioctl_*):
    the driver's version; the adapter's information word; the station
    address; adding or dropping the channel's multicast addresses (the
    adapter's list reloaded when an entry gains its first user or loses
    its last); a new station address, registered with XNS and announced
    by an ARP reply to Apollo's multicast address (the adapter set back
    if XNS refuses it); adding or dropping the channel's packet-type
    ranges, merged with or cut out of the ranges it has; the statistics.
  - The multicast and range requests work under the channel lock; each
    range request checks every range before it changes any.
  - A request that fails after its checks counts in the seventh
    statistic.
  - Adding no multicast addresses stores no status, and the status slot
    is then tested.

  Status stored:
    status_$ok: the request was done
    status_$eth_invalid_unit_num: unit is not 0 or 1
    status_$eth_device_offline: the unit is not on line
    status_$eth_channel_not_open: channel is 0, above 10 or not open
    status_$eth_not_implemented: the request is above 8
    status_$eth_is_multicast: a new station address is a multicast
    status_$eth_driver_version_mismatch: a range request's version is
      above 2
    status_$eth_invalid_pkt_type: a range's low type is above its high
    status_$eth_pkt_type_in_use: a range to add is another's or holds
      the Domain type
    status_$eth_pkt_type_not_in_use: a range to drop is not within one
      of the channel's, or holds the Domain type
    status_$eth_no_channels: the ranges would be more than 32
    status_$eth_invalid_stats_block: the statistics' room is under 42
      bytes
    ethernet_do_cmd's status: the adapter's information
    ethernet_mcast_add's status: a multicast address
    ethernet_load_mcast's status: the reload
    xns_idp_$register_addr's status: a new station address
    ethernet_read_stats's status: the statistics
}

procedure ethernet_$svc_ioctl(var unit: pinteger;
                              var args: ethernet_$ioctl_args_t;
                              unused3: integer; var unused4: univ integer32;
                              out status: status_$t);
  options(val_param);
var
  pcb: ethernet_$pcb_t;
  st2: status_$t;
  mcast: ethernet_$addr_t;
  t: pinteger;
  idx: integer;
  u: ethernet_$unit_ptr_t;
  mask: set of 0..15;
  reload: boolean;
  i: integer;
  j: integer;
  r: integer;
  n: integer;
  k: integer;
  delta: integer;

  { set_station - give the adapter a station address, which must have
    both halves nonzero; the result of the command is not kept, its
    status is. }
  procedure set_station(u: ethernet_$unit_ptr_t;
                        var station: ethernet_$addr_t;
                        out status: status_$t);
  begin
    if (station.high = 0) or else (station.low = 0) then
      crash_system(status_$eth_illegal_dest_address);
    with pcb do begin
      cmd := eth_cmd_set_station_address;
      len := 6;
      addrs[1] := station;
    end;
    discard(ethernet_do_cmd(u, addr(pcb),
                            eth_cmd_set_station_address + eth_cmd_reply,
                            status));
  end;

begin
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;
  u := addr(ether_ucb[unit]);
  if not (eth_unit_online in u^.flags) then begin
    status.all := status_$eth_device_offline;
    return;
  end;
  if (args.channel = 0) or else (args.channel > 10)
     or else not u^.channels[args.channel].open then begin
    status.all := status_$eth_channel_not_open;
    return;
  end;

  case args.req of
    eth_ioctl_get_version: begin
      args.result := eth_open_version;
      status.all := status_$ok;
    end;

    eth_ioctl_adapter_info: begin
      pcb.cmd := eth_cmd_adapter_info;
      pcb.len := 0;
      if ethernet_do_cmd(u, addr(pcb), eth_cmd_adapter_info + eth_cmd_reply,
                         status) then
        args.result := pcb.words[1];
    end;

    eth_ioctl_get_address: begin
      args.station := u^.station;
      status.all := status_$ok;
    end;

    eth_ioctl_add_mcast: begin
      mask := [];
      reload := false;
      ml_$exclusion_start(u^.excl_1098);
      for i := 1 to args.n_addrs do begin
        r := ethernet_mcast_add(args.addrs[i], u^.mcast, u^.mcast_count,
                                status);
        if r <= 0 then begin
          { give back the entries this request took }
          for j := 1 to 15 do
            if j in mask then
              with u^.mcast[j] do
                count := count - 1;
          ml_$exclusion_stop(u^.excl_1098);
          return;
        end;
        if not (r in mask + u^.channels[args.channel].mcast_set) then begin
          with u^.mcast[r] do begin
            count := count + 1;
            if count = 1 then begin
              u^.mcast_count := u^.mcast_count + 1;
              reload := true;
            end;
          end;
          mask := mask + [r];
        end;
      end;
      if reload then
        ethernet_load_mcast(u, status);
      with u^.channels[args.channel] do
        mcast_set := mcast_set + mask;
      ml_$exclusion_stop(u^.excl_1098);
    end;

    eth_ioctl_del_mcast: begin
      reload := false;
      ml_$exclusion_start(u^.excl_1098);
      for i := 1 to args.n_addrs do begin
        r := ethernet_mcast_add(args.addrs[i], u^.mcast, u^.mcast_count,
                                status);
        if (r > 0) and then (r in u^.channels[args.channel].mcast_set) then
        begin
          with u^.mcast[r] do begin
            count := count - 1;
            if count = 0 then begin
              u^.mcast_count := u^.mcast_count - 1;
              reload := true;
            end;
          end;
          with u^.channels[args.channel] do
            mcast_set := mcast_set - [r];
        end;
      end;
      status.all := status_$ok;
      if reload then
        ethernet_load_mcast(u, status);
      ml_$exclusion_stop(u^.excl_1098);
    end;

    eth_ioctl_set_address: begin
      if eth_addr_group in args.addr.first then begin
        status.all := status_$eth_is_multicast;
        return;
      end;
      set_station(u, args.addr, status);
      if status.all = status_$ok then begin
        xns_idp_$register_addr(args.host, ethernet_port_array[u^.cnum],
                               status);
        if status.all = status_$ok then begin
          u^.station := args.addr;
          mcast.high := eth_apollo_mcast_high;
          mcast.low := 1;
          ethernet_arp_reply(u, 0, mcast);
        end
        else
          set_station(u, u^.station, st2);
      end;
    end;

    eth_ioctl_add_types: begin
      if args.version > eth_open_version then begin
        status.all := status_$eth_driver_version_mismatch;
        return;
      end;
      ml_$exclusion_start(u^.excl_1098);

      { check every range; delta: the entries the table gains }
      n := args.count;
      delta := 0;
      for i := 1 to n do
        with args.ranges[i] do begin
          if low > high then begin
            status.all := status_$eth_invalid_pkt_type;
            ml_$exclusion_stop(u^.excl_1098);
            return;
          end;
          if ethernet_range_overlaps(low, high, u^.ranges, u^.range_count)
             or else ((low <= eth_type_domain)
                      and then (eth_type_domain <= high)) then begin
            status.all := status_$eth_pkt_type_in_use;
            ml_$exclusion_stop(u^.excl_1098);
            return;
          end;
          idx := 1;
          ethernet_find_adjacent(u, idx, args.channel, low, high, u^.ranges,
                                 u^.range_count);
          if idx = 0 then
            delta := delta + 1
          else begin
            idx := idx + 1;
            ethernet_find_adjacent(u, idx, args.channel, low, high,
                                   u^.ranges, u^.range_count);
            if idx <> 0 then
              delta := delta - 1;
          end;
        end;
      if u^.range_count + delta > 32 then begin
        status.all := status_$eth_no_channels;
        ml_$exclusion_stop(u^.excl_1098);
        return;
      end;

      { add them: a new entry, or one or two of the channel's extended }
      for i := 1 to n do
        with args.ranges[i] do begin
          idx := 1;
          ethernet_find_adjacent(u, idx, args.channel, low, high, u^.ranges,
                                 u^.range_count);
          if idx = 0 then begin
            u^.ranges[u^.range_count + 1].range := args.ranges[i];
            u^.ranges[u^.range_count + 1].chan := args.channel;
            u^.range_count := u^.range_count + 1;
          end
          else begin
            j := idx;
            idx := idx + 1;
            ethernet_find_adjacent(u, idx, args.channel, low, high,
                                   u^.ranges, u^.range_count);
            if idx = 0 then begin
              if high = u^.ranges[j].low - 1 then
                u^.ranges[j].low := low
              else if low = u^.ranges[j].high + 1 then
                u^.ranges[j].high := high;
            end
            else begin
              { the range joins two: the lower takes the higher's end }
              if u^.ranges[j].low < u^.ranges[idx].low then begin
                u^.ranges[j].high := u^.ranges[idx].high;
                u^.ranges[idx] := u^.ranges[u^.range_count];
              end
              else begin
                u^.ranges[idx].high := u^.ranges[j].high;
                u^.ranges[j] := u^.ranges[u^.range_count];
              end;
              u^.range_count := u^.range_count - 1;
            end;
          end;
        end;
      ml_$exclusion_stop(u^.excl_1098);
      status.all := status_$ok;
    end;

    eth_ioctl_del_types: begin
      if args.version > eth_open_version then begin
        status.all := status_$eth_driver_version_mismatch;
        return;
      end;
      ml_$exclusion_start(u^.excl_1098);

      { check every range; delta: the entries the table loses }
      n := args.count;
      delta := 0;
      for i := 1 to n do
        with args.ranges[i] do begin
          if low > high then begin
            status.all := status_$eth_invalid_pkt_type;
            ml_$exclusion_stop(u^.excl_1098);
            return;
          end;
          k := ethernet_find_range(low, high, u^.ranges, u^.range_count);
          if ((low <= eth_type_domain) and (high >= eth_type_domain))
             or else (high > u^.ranges[k].high)
             or else (low < u^.ranges[k].low)
             or else (k = 0)
             or else (u^.ranges[k].chan <> args.channel) then begin
            status.all := status_$eth_pkt_type_not_in_use;
            ml_$exclusion_stop(u^.excl_1098);
            return;
          end;
          if (low <> u^.ranges[k].low) and then (high <> u^.ranges[k].high)
          then
            delta := delta - 1
          else if (low = u^.ranges[k].low)
                  and then (high = u^.ranges[k].high) then
            delta := delta + 1;
        end;
      if u^.range_count - delta > 32 then begin
        status.all := status_$eth_no_channels;
        ml_$exclusion_stop(u^.excl_1098);
        return;
      end;

      { drop them: an entry removed, cut at one end, or split in two }
      for i := 1 to n do
        with args.ranges[i] do begin
          k := ethernet_find_range(low, high, u^.ranges, u^.range_count);
          if (low = u^.ranges[k].low) and then (high = u^.ranges[k].high)
          then begin
            u^.ranges[k] := u^.ranges[u^.range_count];
            u^.range_count := u^.range_count - 1;
          end
          else if low = u^.ranges[k].low then
            u^.ranges[k].low := high + 1
          else if high = u^.ranges[k].high then
            u^.ranges[k].high := low - 1
          else begin
            t := u^.ranges[k].high;
            u^.ranges[k].high := low - 1;
            u^.ranges[u^.range_count + 1].low := high + 1;
            u^.ranges[u^.range_count + 1].high := t;
            u^.ranges[u^.range_count + 1].chan := args.channel;
            u^.range_count := u^.range_count + 1;
          end;
        end;
      ml_$exclusion_stop(u^.excl_1098);
      status.all := status_$ok;
    end;

    eth_ioctl_get_stats: begin
      if args.max_len < 42 then begin
        args.result := 0;
        status.all := status_$eth_invalid_stats_block;
        return;
      end;
      ethernet_read_stats(unit, args.stats, args.result, status);
      if status.all <> status_$ok then
        args.result := 0;
    end;

    otherwise begin
      status.all := status_$eth_not_implemented;
      return;
    end;
  end;

  if status.all <> status_$ok then
    with u^ do
      stats.counts[7] := stats.counts[7] + 1;
end;
