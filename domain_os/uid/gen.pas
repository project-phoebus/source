{ UID_$GEN - generate a new unique identifier.

  Image addresses:
    sau2  0x00E1A018  UID_$GEN

  - Under the generator's spin lock: the high clock less 16#F0 is the
    UID's high longword when it is above the last one handed out.
  - Otherwise it waits, the lock dropped, until the clock's counter
    nibble moves; then the counter nibble goes up by 1, carrying into
    the high longword when it wraps.
  - abs_clock.low is read before TIME_$ABS_CLOCK first writes it.

  Status stored: none.
}

procedure uid_$gen(out uid_ret: uid_$t);
var
  local_uid: uid_$t;
  clock_val: time_$clockh_t;
  abs_clock: time_$clock_t;
  token: integer32;
  ref_nibble: integer32;
begin
  clock_val := time_$clockh - 16#F0;
  token := ml_$spin_lock(uid_$generator_lock);

  if clock_val > uid_$generator_state.high then
    uid_$generator_state.high := clock_val
  else begin
    { abs_clock is read before TIME_$ABS_CLOCK has written it. }
    ref_nibble := rshft(abs_clock.low, 12);
    repeat
      time_$abs_clock(abs_clock);
      if uid_$generator_state.high <> abs_clock.high then
        exit;
      if uid_$generator_state.low.counter <> ref_nibble then
        exit;
      ml_$spin_unlock(uid_$generator_lock, token);
      repeat
        time_$abs_clock(abs_clock);
      until uid_$generator_state.low.counter <> ref_nibble;
      token := ml_$spin_lock(uid_$generator_lock);
    until false;
  end;

  { hand out the state, bump its counter }
  local_uid := uid_$generator_state.uid;
  uid_$generator_state.counter_byte := uid_$generator_state.counter_byte + 16;
  if uid_$generator_state.low.counter = 0 then
    uid_$generator_state.high := uid_$generator_state.high + 1;

  ml_$spin_unlock(uid_$generator_lock, token);
  uid_ret := local_uid;
end;
