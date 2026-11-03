{ RING_$SET_TMASK - set both units' transmit masks.

  Image addresses:
    sau2  0x00E768E8  RING_$SET_TMASK
    sau3  0x00E780D8  RING_$SET_TMASK
    sau8  0x03C831CE  RING_$SET_TMASK

  - For each unit whose mask differs, as ring_$set_hw_mask, but counting
    RING_$SET_TMASK_CHG_CNT.

  Status stored: none.
}

procedure ring_$set_tmask(in mask: pinteger);
var
  i: integer;
begin
  for i := 0 to 1 do
    with ring_$ctl[i] do
      if mask <> tmask then begin
        if (mask & 16#FF7E) <> 0 then
          state_flags := state_flags + [ring_unit_running]
        else
          state_flags := state_flags - [ring_unit_running];
        tmask := mask;
        state_flags := state_flags + [ring_unit_busy];
        ring_$set_tmask_chg_cnt := ring_$set_tmask_chg_cnt + 1;
        if initialized then
          ec_$advance(rx_wake_ec);
      end;
end;
