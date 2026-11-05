{ RING_8025_$SVC_IOCTL - a user channel's control request.

  Image addresses:
    sau7  0x3C499028  RING_8025_$SVC_IOCTL
    sau8  0x03C8C5F4  RING_8025_$SVC_IOCTL
    sau9  0x3C4881F8  RING_8025_$SVC_IOCTL

  - The driver record's svc_ioctl entry.  The requests (r8025_ioctl_*):
    the driver's version; the adapter's information (0); the station
    address; the functional and group addresses; a new functional or
    group address, given to the adapter under the transmit lock and
    kept when the adapter took it; adding or dropping the channel's
    frame-type ranges (under the channel lock, every range checked
    before any is changed), merged with or cut out of the ranges it has;
    the statistics; the largest frame the unit takes (a new one: 1500,
    2052 or 4472 bytes of data, the MAC header added); whether the unit
    uses source routing.
  - Turning source routing on clears the route cache and takes the
    largest frame back to 2066 bytes; turning it off takes it to 4504.
  - The address, largest-frame and routing requests store no status.
  - The channel is checked only for the range requests.

  Status stored:
    status_$ok: the request was done
    status_$r8025_invalid_unit_num: unit is not 0 or 1
    status_$r8025_device_offline: the unit is not on line
    status_$r8025_not_implemented: the request is above 13
    status_$r8025_channel_not_open: a range request's channel is 0,
      above 10 or not open
    status_$r8025_driver_version_mismatch: a range request's version is
      above 2
    status_$r8025_invalid_frame_type: a range's low type is above its
      high
    status_$r8025_frame_type_in_use: a range to add is another's or holds
      the Domain type
    status_$r8025_frame_type_not_in_use: a range to drop is not within
      one of the channel's, or holds the Domain type
    status_$r8025_no_channels: the ranges would be more than 32
    status_$r8025_adapter_hardware_error: the adapter did not take a new
      address
    status_$r8025_invalid_stats_block: the statistics' room is under 102
      bytes
    ring_8025_wait_scb's status: a new address
    ring_8025_read_stats's status: the statistics
}

procedure ring_8025_$svc_ioctl(var unit: pinteger;
                               var args: ring_8025_$ioctl_args_t;
                               unused3: integer; var unused4: univ integer32;
                               out status: status_$t);
  options(val_param);
var
  fa: ring_8025_$addr_t;
  ga: ring_8025_$addr_t;
  st: status_$t;
  hi: ring_8025_$ftype_t;
  lo: ring_8025_$ftype_t;
  t: linteger;
  idx: integer;
  u: ring_8025_$unit_ptr_t;
  n: integer;
  delta: integer;
  i: integer;
  j: integer;
  k: integer;
  bucket: integer;
  way: integer;
begin
  if unit > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;
  if not (r8025_unit_online in ring8025_ucb[unit].flags) then begin
    status.all := status_$r8025_device_offline;
    return;
  end;

  case args.req of
    r8025_ioctl_get_version: begin
      args.result := r8025_open_version;
      status.all := status_$ok;
    end;

    r8025_ioctl_adapter_info: begin
      args.result := 0;
      status.all := status_$ok;
    end;

    r8025_ioctl_get_address: begin
      args.station.high := r8025_addr_high;
      args.station.low := node_$me;
      status.all := status_$ok;
    end;

    r8025_ioctl_get_funct: begin
      args.station := ring8025_ucb[unit].funct_addr;
    end;

    r8025_ioctl_get_group: begin
      args.station := ring8025_ucb[unit].group_addr;
    end;

    r8025_ioctl_set_funct: begin
      u := addr(ring8025_ucb[unit]);
      fa.high := args.new_addr.high;
      fa.low := args.new_addr.low;
      ml_$exclusion_start(u^.xmit_lock);
      ring_8025_scb_cmd_addr(u, r8025_cmd_set_funct_address, fa);
      ring_8025_wait_scb(u, 5, st);
      if st.all = status_$ok then
        if not u^.cmd_ssb.open_bits.opened then
          st.all := status_$r8025_adapter_hardware_error;
      if st.all = status_$ok then begin
        u^.funct_addr.high := fa.high;
        u^.funct_addr.low := fa.low;
      end;
      ml_$exclusion_stop(u^.xmit_lock);
      status := st;
    end;

    r8025_ioctl_set_group: begin
      u := addr(ring8025_ucb[unit]);
      ga.high := args.new_addr.high;
      ga.low := args.new_addr.low;
      ml_$exclusion_start(u^.xmit_lock);
      ring_8025_scb_cmd_addr(u, r8025_cmd_set_group_address, ga);
      ring_8025_wait_scb(u, 5, st);
      if st.all = status_$ok then
        if not u^.cmd_ssb.open_bits.opened then
          st.all := status_$r8025_adapter_hardware_error;
      if st.all = status_$ok then begin
        u^.group_addr.high := ga.high;
        u^.group_addr.low := ga.low;
      end;
      ml_$exclusion_stop(u^.xmit_lock);
      status := st;
    end;

    r8025_ioctl_add_types: begin
      if (args.channel = 0) or else (args.channel > r8025_max_chan)
         or else not ring8025_ucb[unit].channels[args.channel].open then
      begin
        status.all := status_$r8025_channel_not_open;
        return;
      end;
      if args.version > r8025_open_version then begin
        status.all := status_$r8025_driver_version_mismatch;
        return;
      end;
      u := addr(ring8025_ucb[unit]);
      ml_$exclusion_start(u^.chan_lock);

      { check every range; delta: the entries the table gains }
      n := args.count;
      delta := 0;
      for i := 1 to n do
        with args.ranges[i] do begin
          lo.all := low;
          lo.zero := 0;
          hi.all := high;
          hi.zero := 0;
          if lo.all > hi.all then begin
            status.all := status_$r8025_invalid_frame_type;
            ml_$exclusion_stop(u^.chan_lock);
            return;
          end;
          if ring_8025_range_overlaps(lo.all, hi.all, u^.ranges,
                                      u^.range_count)
             or else ((lo.all <= r8025_type_domain)
                      and then (r8025_type_domain <= hi.all)) then begin
            status.all := status_$r8025_frame_type_in_use;
            ml_$exclusion_stop(u^.chan_lock);
            return;
          end;
          idx := 1;
          ring_8025_find_adjacent(u, idx, args.channel, lo.all, hi.all,
                                  u^.ranges, u^.range_count);
          if idx = 0 then
            delta := delta + 1
          else begin
            idx := idx + 1;
            ring_8025_find_adjacent(u, idx, args.channel, lo.all, hi.all,
                                    u^.ranges, u^.range_count);
            if idx <> 0 then
              delta := delta - 1;
          end;
        end;
      if delta + u^.range_count > 32 then begin
        status.all := status_$r8025_no_channels;
        ml_$exclusion_stop(u^.chan_lock);
        return;
      end;

      { add them: a new entry, or one or two of the channel's extended }
      for i := 1 to n do
        with args.ranges[i] do begin
          lo.all := low;
          lo.zero := 0;
          hi.all := high;
          hi.zero := 0;
          idx := 1;
          ring_8025_find_adjacent(u, idx, args.channel, lo.all, hi.all,
                                  u^.ranges, u^.range_count);
          if idx = 0 then begin
            u^.ranges[u^.range_count + 1].low := lo.all;
            u^.ranges[u^.range_count + 1].high := hi.all;
            u^.ranges[u^.range_count + 1].chan := args.channel;
            u^.range_count := u^.range_count + 1;
          end
          else begin
            j := idx;
            idx := idx + 1;
            ring_8025_find_adjacent(u, idx, args.channel, lo.all, hi.all,
                                    u^.ranges, u^.range_count);
            if idx = 0 then begin
              if hi.all = u^.ranges[j].low - 1 then
                u^.ranges[j].low := lo.all
              else if lo.all = u^.ranges[j].high + 1 then
                u^.ranges[j].high := hi.all;
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
      ml_$exclusion_stop(u^.chan_lock);
      status.all := status_$ok;
    end;

    r8025_ioctl_del_types: begin
      if (args.channel = 0) or else (args.channel > r8025_max_chan)
         or else not ring8025_ucb[unit].channels[args.channel].open then
      begin
        status.all := status_$r8025_channel_not_open;
        return;
      end;
      if args.version > r8025_open_version then begin
        status.all := status_$r8025_driver_version_mismatch;
        return;
      end;
      u := addr(ring8025_ucb[unit]);
      ml_$exclusion_start(u^.chan_lock);

      { check every range; delta: the entries the table loses }
      n := args.count;
      delta := 0;
      for i := 1 to n do
        with args.ranges[i] do begin
          lo.all := low;
          lo.zero := 0;
          hi.all := high;
          hi.zero := 0;
          if lo.all > hi.all then begin
            status.all := status_$r8025_invalid_frame_type;
            ml_$exclusion_stop(u^.chan_lock);
            return;
          end;
          k := ring_8025_find_range(lo.all, hi.all, u^.ranges,
                                    u^.range_count);
          if ((lo.all <= r8025_type_domain) and (hi.all >= r8025_type_domain))
             or else (hi.all > u^.ranges[k].high)
             or else (lo.all < u^.ranges[k].low)
             or else (k = 0)
             or else (u^.ranges[k].chan <> args.channel) then begin
            status.all := status_$r8025_frame_type_not_in_use;
            ml_$exclusion_stop(u^.chan_lock);
            return;
          end;
          if (lo.all <> u^.ranges[k].low)
             and then (hi.all <> u^.ranges[k].high) then
            delta := delta - 1
          else if (lo.all = u^.ranges[k].low)
                  and then (hi.all = u^.ranges[k].high) then
            delta := delta + 1;
        end;
      if u^.range_count - delta > 32 then begin
        status.all := status_$r8025_no_channels;
        ml_$exclusion_stop(u^.chan_lock);
        return;
      end;

      { drop them: an entry removed, cut at one end, or split in two }
      for i := 1 to n do
        with args.ranges[i] do begin
          lo.all := low;
          lo.zero := 0;
          hi.all := high;
          hi.zero := 0;
          k := ring_8025_find_range(lo.all, hi.all, u^.ranges,
                                    u^.range_count);
          if (lo.all = u^.ranges[k].low)
             and then (hi.all = u^.ranges[k].high) then begin
            u^.ranges[k] := u^.ranges[u^.range_count];
            u^.range_count := u^.range_count - 1;
          end
          else if lo.all = u^.ranges[k].low then
            u^.ranges[k].low := hi.all + 1
          else if hi.all = u^.ranges[k].high then
            u^.ranges[k].high := lo.all - 1
          else begin
            t := u^.ranges[k].high;
            u^.ranges[k].high := lo.all - 1;
            u^.ranges[u^.range_count + 1].low := hi.all + 1;
            u^.ranges[u^.range_count + 1].high := t;
            u^.ranges[u^.range_count + 1].chan := args.channel;
            u^.range_count := u^.range_count + 1;
          end;
        end;
      ml_$exclusion_stop(u^.chan_lock);
      status.all := status_$ok;
    end;

    r8025_ioctl_get_stats: begin
      if args.max_len < 102 then begin
        args.result := 0;
        status.all := status_$r8025_invalid_stats_block;
      end
      else begin
        ring_8025_read_stats(unit, args.stats, args.result, status);
        if status.all <> status_$ok then begin
          args.result := 0;
          with ring8025_ucb[unit] do
            stats.cmd_failures := stats.cmd_failures + 1;
        end;
      end;
    end;

    r8025_ioctl_get_max_frame: begin
      args.result := ring8025_ucb[unit].max_frame;
    end;

    r8025_ioctl_set_max_frame: begin
      if (args.value = 4472) or else (args.value = 2052)
         or else (args.value = 1500) then
        ring8025_ucb[unit].max_frame := r8025_mac_hdr_len + args.value;
    end;

    r8025_ioctl_get_routing: begin
      if ring8025_ucb[unit].routing then
        args.result := 1
      else
        args.result := 0;
    end;

    r8025_ioctl_set_routing: begin
      if not ring8025_ucb[unit].routing and then (args.value <> 0) then
      begin
        { the route cache emptied }
        ml_$exclusion_start(ring8025_ucb[unit].route_lock);
        for bucket := 0 to r8025_route_buckets do
          for way := 0 to r8025_route_ways do
            with ring8025_$aux_da.routes[unit, bucket, way] do begin
              station.low := 0;
              expiry := 0;
            end;
        ml_$exclusion_stop(ring8025_ucb[unit].route_lock);
        ring8025_ucb[unit].routing := true;
        ring8025_ucb[unit].max_frame := r8025_max_frame;
      end
      else if ring8025_ucb[unit].routing and then (args.value = 0) then begin
        ring8025_ucb[unit].routing := false;
        ring8025_ucb[unit].max_frame := r8025_frame_size;
      end;
    end;

    otherwise begin
      status.all := status_$r8025_not_implemented;
    end;
  end;
end;
