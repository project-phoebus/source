{ color6_wait_ready - wait for the control word's bit 13.

  Image addresses:
    sau7  0x3C48C98C  color6_wait_ready (module-local)

  - Up to 65520 polls, each after a short spin; the result is whether
    the bit was seen set.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
function color6_wait_ready(regs: color6_$regs_ptr_t): boolean;
var
  count: pinteger;
  i: integer;
  ready: boolean;
begin
  count := 16#FFF0;
  repeat
    for i := 0 to 9 do
      ;
    ready := 13 in regs^.ctl;
    count := count - 1;
  until ready or (count = 0);
  color6_wait_ready := ready;
end;
