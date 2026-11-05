{ OS_$CHECK_POWER_OFF - start the shutdown when power-off is requested.

  Image addresses:
    sau3  0x00E1C6FC  OS_$CHECK_POWER_OFF
    sau4  0x0F81E754  OS_$CHECK_POWER_OFF
    sau5  0x00E1DEB8  OS_$CHECK_POWER_OFF
    sau6  0x7801F5DC  OS_$CHECK_POWER_OFF

  - Compiled only with `power_off_check' (base/config.ins.pas).
  - The repeating element's callback (OS_$INIT_POWER_OFF_CHECK), about
    every two seconds at interrupt level: advances OS_$SHUTDOWN_EC the
    first time the request is set, which starts the shutdown.
  - Its static, the last state, lies in the module's WIRED_DATA block
    after OS_$INIT_POWER_OFF_CHECK's element, so the routine is headed
    with WIRED_DATA as its data section.

  Status stored: none.
}

%if power_off_check %then
[section(wired_proc, wired_data)]
procedure os_$check_power_off;
var
  off: boolean;
  last_off: static boolean := false;      { WIRED_DATA +0x1C }
begin
  off := mmu_$power_off;
  if off and then not last_off then
    advance(ec_$eventcount_ptr_t(addr(os_$shutdown_ec))^);
  last_off := off;
end;
%endif
