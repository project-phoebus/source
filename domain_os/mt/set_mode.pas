{ MT_$SET_MODE - set a magnetic tape unit's mode bits.

  Image addresses:
    sau3  0x00E70BB8  MT_$SET_MODE
    sau4  0x0F87D930  MT_$SET_MODE
    sau5  0x00E76722  MT_$SET_MODE
    sau6  0x7807D3CE  MT_$SET_MODE

  - Each member of mode clears or sets one bit of the unit's state
    (mt/mt.ins.pas); both of the flag 9 pair are accepted (set wins).
    The new mode_bits go into each request queued afterwards.
  - The third parameter is not read.

  Status stored:
    mt_$queue_request's status: the unit was checked, or not
    status_$mt_invalid_mode: mode asks to clear and set the same bit, or
      has a member of 10..15
}

procedure mt_$set_mode;
var
  u: integer;
begin
  u := unit;
  mt_$queue_request(u, mt_op_check, 0, 0, 0, status);
  if status.all <> 0 then
    return;
  if ((mt_mode_batch_on in mode) and (mt_mode_batch_off in mode))
     or else ((mt_mode_clear_12 in mode) and (mt_mode_set_12 in mode))
     or else ((mt_mode_clear_10 in mode) and (mt_mode_set_10 in mode))
     or else (mode * [10..15] <> [])
     or else ((mt_mode_clear_11 in mode) and then (mt_mode_set_11 in mode))
  then begin
    status.all := status_$mt_invalid_mode;
    return;
  end;
  with mt_$scb.units[u] do begin
    if mt_mode_clear_11 in mode then
      mode_bits.bits := mode_bits.bits - [mt_mode_bit_11];
    if mt_mode_set_11 in mode then
      mode_bits.bits := mode_bits.bits + [mt_mode_bit_11];
    if mt_mode_clear_10 in mode then
      mode_bits.bits := mode_bits.bits - [mt_mode_bit_10];
    if mt_mode_set_10 in mode then
      mode_bits.bits := mode_bits.bits + [mt_mode_bit_10];
    if mt_mode_clear_12 in mode then
      mode_bits.bits := mode_bits.bits - [mt_mode_bit_12];
    if mt_mode_set_12 in mode then
      mode_bits.bits := mode_bits.bits + [mt_mode_bit_12];
    if mt_mode_batch_on in mode then
      flags.bits := flags.bits + [mt_unit_batch];
    if mt_mode_batch_off in mode then
      flags.bits := flags.bits - [mt_unit_batch];
    if mt_mode_clear_flag_9 in mode then
      flags.bits := flags.bits - [mt_unit_flag_9];
    if mt_mode_set_flag_9 in mode then
      flags.bits := flags.bits + [mt_unit_flag_9];
  end;
end;
