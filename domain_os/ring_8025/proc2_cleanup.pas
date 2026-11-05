{ RING_8025_$PROC2_CLEANUP - close every channel an address space holds.

  Image addresses:
    sau7  0x3C4998AC  RING_8025_$PROC2_CLEANUP
    sau8  0x03C8CE78  RING_8025_$PROC2_CLEANUP
    sau9  0x3C488A7C  RING_8025_$PROC2_CLEANUP

  - The driver record's proc2_cleanup entry.  On a unit on line, under
    the channel lock, each channel the address space opened is closed
    as RING_8025_$SVC_CLOSE closes it, and the unit's LLC classes are
    made again from class 1 and the classes of the channels still open.
  - Under the unit's lock the users drop by the channels closed: the
    last stops the receive process.  The driver is unwired once however
    many channels were closed.

  Status stored: none.
}

procedure ring_8025_$proc2_cleanup(var unit: pinteger; asid: integer);
  options(val_param);
var
  u: ring_8025_$unit_ptr_t;
  closed: integer;
  ch: integer;
  j: pinteger;
  cls: integer;
  i: integer;
begin
  if unit <= r8025_max_unit then begin
    u := addr(ring8025_ucb[unit]);
    if r8025_unit_online in ring8025_ucb[unit].flags then begin
      ml_$exclusion_start(u^.chan_lock);
      closed := 0;
      for ch := 1 to r8025_max_chan do
        if u^.channels[ch].open
           and then (u^.channels[ch].asid = asid) then begin
          u^.channels[ch].open := false;
          if u^.channels[ch].socket <> r8025_os_socket then
            ring_8025_close_socket(u^.channels[ch].socket);

          { its ranges }
          j := 1;
          while j <= u^.range_count do
            if ch = u^.ranges[j].chan then begin
              u^.ranges[j] := u^.ranges[u^.range_count];
              u^.range_count := u^.range_count - 1;
            end
            else
              j := j + 1;
          closed := closed + 1;
        end;

      { the LLC classes of the channels left }
      cls := 1;
      for i := 1 to r8025_max_chan do
        if u^.channels[i].open then
          cls := cls ! u^.channels[i].llc_class;
      u^.llc_class := cls;
      ml_$exclusion_stop(u^.chan_lock);

      { the unit }
      ml_$exclusion_start(u^.lock);
      u^.users := u^.users - closed;
      if u^.users = 0 then
        ring_8025_stop_rcv(u);
      ml_$exclusion_stop(u^.lock);
      if closed <> 0 then
        ring_8025_unwire_driver;
    end;
  end;
end;
