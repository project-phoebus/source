{ RING_$SVC_IOCTL - a channel's control request (the driver's svc_ioctl).

  Image addresses:
    sau2  0x00E776B8  RING_$SVC_IOCTL
    sau3  0x00E78EA8  RING_$SVC_IOCTL
    sau8  0x03C83F7A  RING_$SVC_IOCTL

  - Command 1 answers 1; 2 adds packet-type ranges to the channel
    (merged with its adjoining entries, or appended); 3 removes ranges
    (each inside one of the channel's entries).
  - 4 copies out the unit's statistics.  The table's growth is checked
    before any change.
  - Command 3 reads the found entry's bounds before it tests found = 0.

  Status stored:
    status_$ok: the command was done
    status_$ring_invalid_unit_num: unit is above 1
    status_$ring_device_offline: not started, or neither running nor
      open
    status_$ring_channel_not_open: the channel is not 1..10 and open
    status_$ring_driver_version_mismatch: args.version is above 1
    status_$ring_invalid_svc_packet_type: a range's low is above its high
    status_$ring_pkt_type_in_use: a range to add meets the table's
    status_$ring_no_channels: the table would grow past 32 entries
    status_$ring_pkt_type_not_in_use: a range to remove is in none of
      the channel's entries
    status_$ring_invalid_stats_block: the buffer is under 60 bytes
    status_$ring_not_implemented: any other command
}

procedure ring_$svc_ioctl(var unit: pinteger;
                          var args: ring_$svc_ioctl_args_t;
                          param4: integer; var param5: univ integer32;
                          out status: status_$t);
  options(val_param);
var
  adj: integer;
  u: ring_$unit_ptr_t;
  delta: integer;
  first: integer;
  found: integer;
  old_high: linteger;
  j: integer;
begin
  if unit > 1 then begin
    status.all := status_$ring_invalid_unit_num;
    return;
  end;

  u := addr(ring_$ctl[unit]);
  if not (ring_unit_started in u^.state_flags)
     or else (not (ring_unit_running in u^.state_flags)
              and then (u^.open_count = 0)) then begin
    status.all := status_$ring_device_offline;
    return;
  end;
  if (args.channel = 0) or else (args.channel > 10)
     or else not u^.channels[args.channel].flags then begin
    status.all := status_$ring_channel_not_open;
    return;
  end;

  case args.cmd of
    ring_$ioctl_nop: begin
         args.cmd := 1;
         status.all := 0;
       end;

    ring_$ioctl_add_types: begin
         { check, count the change }
         if args.version > 1 then begin
           status.all := status_$ring_driver_version_mismatch;
           return;
         end;
         ml_$exclusion_start(u^.rx_exclusion);
         delta := 0;
         for j := 1 to args.count do
           with args.ranges[j] do begin
             if low > high then begin
               status.all := status_$ring_invalid_svc_packet_type;
               ml_$exclusion_stop(u^.rx_exclusion);
               return;
             end;
             if ring_$pkt_type_overlaps(low, high, u^.pkt_types,
                                        u^.pkt_type_cnt) then begin
               status.all := status_$ring_pkt_type_in_use;
               ml_$exclusion_stop(u^.rx_exclusion);
               return;
             end;
             adj := 1;
             ring_$find_adjacent_pkt_type(u^, adj, args.channel, low, high,
                                          u^.pkt_types, u^.pkt_type_cnt);
             if adj = 0 then
               delta := delta + 1
             else begin
               adj := adj + 1;
               ring_$find_adjacent_pkt_type(u^, adj, args.channel, low,
                                            high, u^.pkt_types,
                                            u^.pkt_type_cnt);
               if adj <> 0 then
                 delta := delta - 1;
             end;
           end;

         if delta + u^.pkt_type_cnt > 32 then begin
           status.all := status_$ring_no_channels;
           ml_$exclusion_stop(u^.rx_exclusion);
           return;
         end;

         { add }
         for j := 1 to args.count do
           with args.ranges[j] do begin
             adj := 1;
             ring_$find_adjacent_pkt_type(u^, adj, args.channel, low, high,
                                          u^.pkt_types, u^.pkt_type_cnt);
             if adj = 0 then begin
               u^.pkt_types[u^.pkt_type_cnt + 1].entry.range :=
                 args.ranges[j];
               u^.pkt_types[u^.pkt_type_cnt + 1].entry.channel :=
                 args.channel;
               u^.pkt_type_cnt := u^.pkt_type_cnt + 1;
             end
             else begin
               first := adj;
               adj := first + 1;
               ring_$find_adjacent_pkt_type(u^, adj, args.channel, low,
                                            high, u^.pkt_types,
                                            u^.pkt_type_cnt);
               found := adj;
               if found = 0 then begin
                 { extend one entry }
                 if u^.pkt_types[first].entry.range.low - 1 = high then
                   u^.pkt_types[first].entry.range.low := low
                 else if u^.pkt_types[first].entry.range.high + 1 = low then
                   u^.pkt_types[first].entry.range.high := high;
               end
               else begin
                 { the range joins two entries }
                 if u^.pkt_types[first].entry.range.low
                    < u^.pkt_types[found].entry.range.low then begin
                   u^.pkt_types[first].entry.range.high :=
                     u^.pkt_types[found].entry.range.high;
                   u^.pkt_types[found].entry :=
                     u^.pkt_types[u^.pkt_type_cnt].entry;
                 end
                 else begin
                   u^.pkt_types[found].entry.range.high :=
                     u^.pkt_types[first].entry.range.high;
                   u^.pkt_types[first].entry :=
                     u^.pkt_types[u^.pkt_type_cnt].entry;
                 end;
                 u^.pkt_type_cnt := u^.pkt_type_cnt - 1;
               end;
             end;
           end;
         ml_$exclusion_stop(u^.rx_exclusion);
         status.all := 0;
       end;

    ring_$ioctl_remove_types: begin
         { check, count the change }
         if args.version > 1 then begin
           status.all := status_$ring_driver_version_mismatch;
           return;
         end;
         ml_$exclusion_start(u^.rx_exclusion);
         delta := 0;
         for j := 1 to args.count do
           with args.ranges[j] do begin
             if low > high then begin
               status.all := status_$ring_invalid_svc_packet_type;
               ml_$exclusion_stop(u^.rx_exclusion);
               return;
             end;
             found := ring_$find_overlapping_pkt_type(low, high,
                                                     u^.pkt_types,
                                                     u^.pkt_type_cnt);
             if (high > u^.pkt_types[found].entry.range.high)
                or else (low < u^.pkt_types[found].entry.range.low)
                or else (found = 0)
                or else (u^.pkt_types[found].entry.channel
                         <> args.channel) then begin
               status.all := status_$ring_pkt_type_not_in_use;
               ml_$exclusion_stop(u^.rx_exclusion);
               return;
             end;
             if (low <> u^.pkt_types[found].entry.range.low)
                and then (high <> u^.pkt_types[found].entry.range.high) then
               delta := delta - 1
             else if (low = u^.pkt_types[found].entry.range.low)
                     and then (high = u^.pkt_types[found].entry.range.high)
                     then
               delta := delta + 1;
           end;

         if u^.pkt_type_cnt - delta > 32 then begin
           status.all := status_$ring_no_channels;
           ml_$exclusion_stop(u^.rx_exclusion);
           return;
         end;

         { remove }
         for j := 1 to args.count do
           with args.ranges[j] do begin
             found := ring_$find_overlapping_pkt_type(low, high,
                                                     u^.pkt_types,
                                                     u^.pkt_type_cnt);
             if (low = u^.pkt_types[found].entry.range.low)
                and then (high = u^.pkt_types[found].entry.range.high)
                then begin
               u^.pkt_types[found].entry :=
                 u^.pkt_types[u^.pkt_type_cnt].entry;
               u^.pkt_type_cnt := u^.pkt_type_cnt - 1;
             end
             else if low = u^.pkt_types[found].entry.range.low then
               u^.pkt_types[found].entry.range.low := high + 1
             else if high = u^.pkt_types[found].entry.range.high then
               u^.pkt_types[found].entry.range.high := low - 1
             else begin
               old_high := u^.pkt_types[found].entry.range.high;
               u^.pkt_types[found].entry.range.high := low - 1;
               u^.pkt_types[u^.pkt_type_cnt + 1].entry.range.low := high + 1;
               u^.pkt_types[u^.pkt_type_cnt + 1].entry.range.high :=
                 old_high;
               u^.pkt_types[u^.pkt_type_cnt + 1].entry.channel :=
                 args.channel;
               u^.pkt_type_cnt := u^.pkt_type_cnt + 1;
             end;
           end;
         ml_$exclusion_stop(u^.rx_exclusion);
         status.all := 0;
       end;

    ring_$ioctl_get_stats: begin
         if args.buf_len < 60 then begin
           status.all := status_$ring_invalid_stats_block;
           return;
         end;
         args.buf^ := ring_$data[unit];
         args.cmd := 60;
         status.all := 0;
       end;

    otherwise begin
      status.all := status_$ring_not_implemented;
    end;
  end;
end;
