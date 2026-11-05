{ ring_$set_hw_mask - change a unit's transmit mask.

  Image addresses:
    sau2  0x00E767CC  ring_$set_hw_mask (module-local)
    sau6  0x78084DDE  ring_$set_hw_mask (module-local)
    sau7  0x3C48F8B2  ring_$set_hw_mask (module-local)
    sau8  0x03C830B2  ring_$set_hw_mask (module-local)

  - A new mask is kept in the unit, which is running when the mask has
    any bit but 0 and 7; the unit is marked busy and an initialized
    unit's receive process woken to load it.  The same mask changes
    nothing.

  Status stored: none.
}

procedure ring_$set_hw_mask(unit: integer; mask: pinteger); internal;
var
  u: ring_$unit_ptr_t;
begin
  u := addr(ring_$ctl[unit]);
  if mask <> u^.tmask then begin
    if (mask & 16#FF7E) <> 0 then
      u^.state_flags := u^.state_flags + [ring_unit_running]
    else
      u^.state_flags := u^.state_flags - [ring_unit_running];
    u^.tmask := mask;
    u^.state_flags := u^.state_flags + [ring_unit_busy];
    ring_$unit_tmask_chg_cnt := ring_$unit_tmask_chg_cnt + 1;
    if u^.initialized then
      ec_$advance(u^.rx_wake_ec);
  end;
end;
