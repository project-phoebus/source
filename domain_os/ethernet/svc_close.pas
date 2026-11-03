{ ETHERNET_$SVC_CLOSE - close a user channel.

  Image addresses:
    sau8  0x03C86F80  ETHERNET_$SVC_CLOSE
    sau9  0x3C482B80  ETHERNET_$SVC_CLOSE

  - The driver record's svc_close entry, and ETHERNET_$CLOSE_OS's.
    Under the channel lock the channel is closed, its socket closed
    (unless it is the system's), its ranges taken out of the table and
    its multicast addresses let go; the adapter's list is reloaded when
    an address lost its last user.
  - Under the unit's lock the close is uncounted: the last user stops
    the receive process; when only the Domain user is left the 82586
    goes back to receive mode 2.  A failure to reload or reconfigure
    counts in the unit's seventh statistic and is not returned.

  Status stored:
    status_$ok: the channel was closed
    status_$eth_invalid_unit_num: unit is not 0 or 1
    status_$eth_channel_not_open: channel is 0, above 10 or not open
}

procedure ethernet_$svc_close(var unit: pinteger; var channel: pinteger;
                              unused3: integer; var unused4: univ integer32;
                              out status: status_$t);
  options(val_param);
var
  u: ethernet_$unit_ptr_t;
  j: pinteger;
  i: integer;
  reload: boolean;
begin
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;
  u := addr(ether_ucb[unit]);
  ml_$exclusion_start(u^.excl_1098);
  if (channel = 0) or else (channel > 10)
     or else not u^.channels[channel].open then begin
    ml_$exclusion_stop(u^.excl_1098);
    status.all := status_$eth_channel_not_open;
    return;
  end;
  u^.channels[channel].open := false;
  if u^.channels[channel].socket <> eth_os_socket then
    sock_$close(u^.channels[channel].socket);

  { its ranges }
  j := 1;
  while j <= u^.range_count do
    if u^.ranges[j].chan = channel then begin
      u^.ranges[j] := u^.ranges[u^.range_count];
      u^.range_count := u^.range_count - 1;
    end
    else
      j := j + 1;

  { its multicast addresses }
  reload := false;
  for i := 1 to 15 do
    if i in u^.channels[channel].mcast_set then
      with u^.mcast[i] do begin
        count := count - 1;
        if count = 0 then begin
          u^.mcast_count := u^.mcast_count - 1;
          reload := true;
        end;
      end;
  if reload then begin
    ethernet_load_mcast(u, status);
    if status.all <> status_$ok then
      with u^ do
        stats.counts[7] := stats.counts[7] + 1;
  end;
  ml_$exclusion_stop(u^.excl_1098);

  { the unit }
  ml_$exclusion_start(u^.lock);
  u^.users := u^.users - 1;
  if u^.users = 0 then
    ethernet_stop_rcv(u)
  else if (u^.users = 1) and then (eth_unit_domain in u^.flags) then begin
    ethernet_configure(u, false, status);
    if status.all <> status_$ok then
      with u^ do
        stats.counts[7] := stats.counts[7] + 1;
  end;
  ml_$exclusion_stop(u^.lock);
  status.all := status_$ok;
  ethernet_unwire_driver;
end;
