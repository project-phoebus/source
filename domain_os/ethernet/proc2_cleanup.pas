{ ETHERNET_$PROC2_CLEANUP - close every channel an address space holds.

  Image addresses:
    sau9  0x3C483C4C  ETHERNET_$PROC2_CLEANUP

  - The driver record's proc2_cleanup entry.  On a unit on line, under
    the channel lock, each channel the address space opened is closed
    as ETHERNET_$SVC_CLOSE closes it; then, under the unit's lock, the
    users drop by the channels closed, as there.
  - A failed multicast reload is not counted; a failed reconfigure
    counts in the seventh statistic.
  - The driver is unwired once however many channels were closed.

  Status stored: none.
}

procedure ethernet_$proc2_cleanup(var unit: pinteger; asid: integer);
  options(val_param);
var
  st: status_$t;
  u: ethernet_$unit_ptr_t;
  closed: integer;
  ch: integer;
  j: pinteger;
  i: integer;
  reload: boolean;
begin
  if unit <= eth_max_unit then begin
    u := addr(ether_ucb[unit]);
    if eth_unit_online in ether_ucb[unit].flags then begin
      ml_$exclusion_start(u^.excl_1098);
      closed := 0;
      for ch := 1 to 10 do
        if u^.channels[ch].open
           and then (u^.channels[ch].asid = asid) then begin
          u^.channels[ch].open := false;
          if u^.channels[ch].socket <> eth_os_socket then
            sock_$close(u^.channels[ch].socket);

          { its ranges }
          j := 1;
          while j <= u^.range_count do
            if ch = u^.ranges[j].chan then begin
              u^.ranges[j] := u^.ranges[u^.range_count];
              u^.range_count := u^.range_count - 1;
            end
            else
              j := j + 1;

          { its multicast addresses }
          reload := false;
          for i := 1 to 15 do
            if i in u^.channels[ch].mcast_set then
              with u^.mcast[i] do begin
                count := count - 1;
                if count = 0 then begin
                  u^.mcast_count := u^.mcast_count - 1;
                  reload := true;
                end;
              end;
          if reload then
            ethernet_load_mcast(u, st);
          closed := closed + 1;
        end;
      ml_$exclusion_stop(u^.excl_1098);

      { the unit }
      ml_$exclusion_start(u^.lock);
      u^.users := u^.users - closed;
      if u^.users = 0 then
        ethernet_stop_rcv(u)
      else if (u^.users = 1) and then (eth_unit_domain in u^.flags) then begin
        ethernet_configure(u, false, st);
        if st.all <> status_$ok then
          with u^ do
            stats.counts[7] := stats.counts[7] + 1;
      end;
      ml_$exclusion_stop(u^.lock);
      if closed <> 0 then
        ethernet_unwire_driver;
    end;
  end;
end;
