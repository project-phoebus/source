{ RING_$PROC2_CLEANUP - close every channel an address space holds.

  Image addresses:
    sau2  0x00E76A42  RING_$PROC2_CLEANUP
    sau3  0x00E78232  RING_$PROC2_CLEANUP
    sau8  0x03C83322  RING_$PROC2_CLEANUP

  - On a started unit, under the channel lock, each channel the address
    space opened is closed (RING_$SVC_CLOSE's steps); then, under the
    transmit lock, the open count drops by the channels closed.

  Status stored: none.
}

procedure ring_$proc2_cleanup(var socket: pinteger; asid: integer);
  options(val_param);
var
  u: ring_$unit_ptr_t;
  closed: integer;
  ch: integer;
  j: pinteger;
begin
  if socket <= 1 then begin
    u := addr(ring_$ctl[socket]);
    if ring_unit_started in u^.state_flags then begin
      ml_$exclusion_start(u^.rx_exclusion);
      closed := 0;
      for ch := 1 to 10 do
        if u^.channels[ch].flags
           and then (asid = u^.channels[ch].asid) then begin
          u^.channels[ch].flags := false;
          if u^.channels[ch].socket_id <> ring_os_socket then
            sock_$close(u^.channels[ch].socket_id);
          j := 1;
          while j <= u^.pkt_type_cnt do
            if ch = u^.pkt_types[j].entry.channel then begin
              u^.pkt_types[j].entry := u^.pkt_types[u^.pkt_type_cnt].entry;
              u^.pkt_type_cnt := u^.pkt_type_cnt - 1;
            end
            else
              j := j + 1;
          closed := closed + 1;
        end;
      ml_$exclusion_stop(u^.rx_exclusion);

      ml_$exclusion_start(u^.tx_exclusion);
      u^.open_count := u^.open_count - closed;
      ml_$exclusion_stop(u^.tx_exclusion);
    end;
  end;
end;
