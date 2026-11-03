%if ct_atbus_qic02 %then
{ RESET_DRIVE - reset the tape adapter.

  Image addresses:
    sau8  0x03C7A59E  RESET_DRIVE

  - With the AT bus adapter (`ct_atbus_qic02'): its DMA is reset and
    the reset held for 2 x 65536 clock ticks; then the interrupt is
    enabled, the eventcount's next value taken, and the PBU unit's
    interrupt enabled (PBU_$ENABLE_DEVICE).  The reset's end is
    CT_WAIT's to see.

  Status stored: none.
}

procedure reset_drive;
var
  regs: ct_$atbus_regs_ptr_t;
  hold: time_$clock_t;
  status: status_$t;
begin
  ct_cmd := 0;
  regs := ct_regs;
  regs^.dma_reset := 0;
  regs^.ctl := ct_ctl_reset;
  hold.high := 2;
  hold.low := 0;
  time_$wait(time_$relative, hold, status);
  regs^.ctl := 0;
  ct_wait_value := ct_ec.value + 1;
  regs^.ctl := ct_ctl_int_enable;
  pbu_$enable_device(ct_pbu_unit, status);
end;
%else
{ RESET_DRIVE - reset the tape controller, or crash.

  Image addresses:
    sau5  0x00E771B2  RESET_DRIVE

  - Up to three tries of the reset command and a 480-tick wait (no
    quit); success or a warning ends it, as does "controller timeout".
  - Three failures with a positive status code other than "controller
    timeout" crash the system with that status.

  Status stored: none.
}

procedure reset_drive;
var
  i: integer;
  status: status_$t;
begin
  ct_reading := true;
  for i := 1 to 3 do begin
    status.all := do_ctl_cmd(ct_cmd_reset, ct_count_unlocked);
    if status.all = 0 then
      status.all := ct_wait(480, false);
    if status.code <= 0 then
      return;
    if status.all = status_$ct_controller_timeout then
      exit;
  end;
  if (status.code > 0)
     and then (status.all <> status_$ct_controller_timeout) then
    crash_system(status);
end;
%endif
