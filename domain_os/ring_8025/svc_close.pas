{ RING_8025_$SVC_CLOSE - close a user channel.

  Image addresses:
    sau8  0x03C8BDB6  RING_8025_$SVC_CLOSE
    sau9  0x3C4879BA  RING_8025_$SVC_CLOSE

  - The driver record's svc_close entry.  Under the channel lock the
    channel is closed, its socket closed (unless it is the system's),
    the unit's LLC classes made again from class 1 and the classes of
    the channels still open, and the channel's ranges taken out of the
    table.
  - Under the unit's lock the close is uncounted: the last user stops
    the receive process.  The driver is unwired once for the channel.

  Status stored:
    status_$ok: the channel was closed
    status_$r8025_invalid_unit_num: unit is not 0 or 1
    status_$r8025_channel_not_open: channel is 0, above 10 or not open
}

procedure ring_8025_$svc_close(var unit: pinteger; var channel: pinteger;
                               unused3: integer; var unused4: univ integer32;
                               out status: status_$t);
  options(val_param);
var
  u: ring_8025_$unit_ptr_t;
  cls: integer;
  j: pinteger;
  i: integer;
begin
  if unit > r8025_max_unit then begin
    status.all := status_$r8025_invalid_unit_num;
    return;
  end;
  u := addr(ring8025_ucb[unit]);
  ml_$exclusion_start(u^.chan_lock);
  if (channel = 0) or else (channel > r8025_max_chan)
     or else not u^.channels[channel].open then begin
    ml_$exclusion_stop(u^.chan_lock);
    status.all := status_$r8025_channel_not_open;
    return;
  end;
  u^.channels[channel].open := false;
  if u^.channels[channel].socket <> r8025_os_socket then
    ring_8025_close_socket(u^.channels[channel].socket);

  { the LLC classes of the channels left }
  cls := 1;
  for i := 1 to r8025_max_chan do
    if u^.channels[i].open then
      cls := cls ! u^.channels[i].llc_class;
  u^.llc_class := cls;

  { its ranges }
  j := 1;
  while j <= u^.range_count do
    if u^.ranges[j].chan = channel then begin
      u^.ranges[j] := u^.ranges[u^.range_count];
      u^.range_count := u^.range_count - 1;
    end
    else
      j := j + 1;
  ml_$exclusion_stop(u^.chan_lock);

  { the unit }
  ml_$exclusion_start(u^.lock);
  u^.users := u^.users - 1;
  if u^.users = 0 then
    ring_8025_stop_rcv(u);
  ml_$exclusion_stop(u^.lock);
  status.all := status_$ok;
  ring_8025_unwire_driver;
end;
