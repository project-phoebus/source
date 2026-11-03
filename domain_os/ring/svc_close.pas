{ RING_$SVC_CLOSE - close a channel (the driver's svc_close).

  Image addresses:
    sau2  0x00E76E22  RING_$SVC_CLOSE
    sau3  0x00E78612  RING_$SVC_CLOSE
    sau8  0x03C836FA  RING_$SVC_CLOSE

  - Under the channel lock the channel's socket (unless the system's) is
    closed and its packet types removed, each replaced by the last; then,
    under the transmit lock, the open count drops by one.

  Status stored:
    status_$ok: the channel was closed
    status_$ring_invalid_unit_num: unit is above 1
    status_$ring_channel_not_open: the channel is not 1..10 and open
}

procedure ring_$svc_close(var unit: pinteger; var channel: pinteger;
                          unused3: integer; var unused4: univ integer32;
                          out status: status_$t);
  options(val_param);
var
  u: ring_$unit_ptr_t;
  j: pinteger;
begin
  if unit > 1 then
    status.all := status_$ring_invalid_unit_num
  else begin
    u := addr(ring_$ctl[unit]);
    ml_$exclusion_start(u^.rx_exclusion);
    if (channel = 0) or else (channel > 10)
       or else not u^.channels[channel].flags then begin
      ml_$exclusion_stop(u^.rx_exclusion);
      status.all := status_$ring_channel_not_open;
    end
    else begin
      u^.channels[channel].flags := false;
      if u^.channels[channel].socket_id <> ring_os_socket then
        sock_$close(u^.channels[channel].socket_id);
      j := 1;
      while j <= u^.pkt_type_cnt do
        if u^.pkt_types[j].entry.channel = channel then begin
          u^.pkt_types[j].entry := u^.pkt_types[u^.pkt_type_cnt].entry;
          u^.pkt_type_cnt := u^.pkt_type_cnt - 1;
        end
        else
          j := j + 1;
      ml_$exclusion_stop(u^.rx_exclusion);
      ml_$exclusion_start(u^.tx_exclusion);
      u^.open_count := u^.open_count - 1;
      ml_$exclusion_stop(u^.tx_exclusion);
      status.all := 0;
    end;
  end;
end;
