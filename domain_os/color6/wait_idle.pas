{ color6_wait_idle - wait until the board's FIFO is empty and idle.

  Image addresses:
    sau7  0x3C48CB6A  color6_wait_idle (module-local)

  - The FIFO's count is polled while it falls, up to 32767 times while
    it stays; a count that grows gives false.
  - The control word's bit 11 is then set and polled up to 8192 times:
    true when it clears.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
function color6_wait_idle(dcte: color6_$dcte_ptr_t): boolean;
  internal;
var
  info: color6_$info_ptr_t;
  tries: integer;
  count: pinteger;
  last: pinteger;
  regs: color6_$regs_ptr_t;
  i: integer;
begin
  color6_wait_idle := false;
  info := dcte^.info;
  tries := 32767;
  count := 16#FFFF;
  repeat
    last := count;
    count := color6_fifo_count(dcte);
    if count = 0 then
      exit;
    if count < last then
      tries := 32767
    else if count = last then
      tries := tries - 1
    else
      return;
  until tries = 0;
  if count <> 0 then
    return;
  regs := info^.regs;
  regs^.ctl := regs^.ctl + [11];
  for i := 1 to 8192 do
    if not (11 in regs^.ctl) then begin
      color6_wait_idle := true;
      return;
    end;
end;
