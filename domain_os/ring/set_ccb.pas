{ ring_$set_ccb - give the controller a unit's command block.

  Image addresses:
    sau7  0x3C48DE0C  ring_$set_ccb (module-local)
    sau8  0x03C8160C  ring_$set_ccb (module-local)
    sau9  0x3C47D20C  ring_$set_ccb (module-local)

  - RING_$CCB's element goes, in the controller's form, to the unit's
    command area; with locked, under the unit's buffer lock.
  - The controller is told to load it and polled up to 8193 times; a
    block it does not accept leaves the command word cleared.

  Returns:
    0: the controller took the block
    status_$network_hardware_error: it never answered

  Status stored: none.
}

function ring_$set_ccb(unit: integer; locked: boolean): integer32;
  internal;
type
  { The command block in the controller's form. }
  ctlr_ccb_t = record
    node: linteger;                       { 0x00 }
    tmask: ring_$byte_t;                  { 0x04 }
    zero_05: ring_$byte_t;                { 0x05 }
    zero_06: ring_$byte_t;                { 0x06 }
    mode: ring_$byte_t;                   { 0x07 }
  end;
var
  hw: ring8_$csr_ptr_t;
  cmd: ctlr_ccb_t;
  cmd_ptr: ^ctlr_ccb_t;
  addr_w: pinteger;
  st: ring8_$csr_set_t;
  i: integer;
begin
  hw := ring_$ctl[unit].hw_regs;
  cmd_ptr := addr(cmd);
  cmd.node := ring_$ccb[unit].node;
  cmd.tmask := ring_$ccb[unit].tmask;
  cmd.zero_05 := 0;
  cmd.zero_06 := 0;
  cmd.mode := ring_$ccb[unit].mode;
  if locked then
    ml_$exclusion_start(ring_$ctl[unit].buf_lock);
  ring_$rb_to(hw^, ring_$ctl[unit].cmd_addr, cmd_ptr, 4);

  { point the controller at the block and load it }
  addr_w := ring_$ctl[unit].cmd_addr;
  hw^.cmd_ptr := lshft(addr_w & 16#FF, 8) + rshft(addr_w, 8);
  hw^.command := [8];
  for i := 1 to 8193 do begin
    st := hw^.command;
    if 5 in st then
      exit;
  end;
  if locked then
    ml_$exclusion_stop(ring_$ctl[unit].buf_lock);

  if 5 in st then
    ring_$set_ccb := 0
  else begin
    ring_$set_ccb := status_$network_hardware_error;
    hw^.command := [];
  end;
end;
