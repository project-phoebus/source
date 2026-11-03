{ DISK_INTERRUPT - the disk controllers' first-level interrupt routine.

  Image addresses:
    sau2  0x00E0AABC  DISK_INTERRUPT

  - The floppy (type-1) and Winchester (type-0) controllers share one
    register block and one vector.
  - The status word at +6 hands the interrupt to FLP_$INT for bit 10,
    else to WIN_$INT for bits 11 or 12; one neither claims crashes.
  - The first routine of the ATBUS_ module (sysbus/atbus_.pas); the map
    symbol has no `$'.  Compiled only with `winchester_config'
    (base/config.ins.pas): the SAU3 has no system bus disk controller.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure disk_interrupt;
var
  regs: flp_$regs_ptr_t;
  status: set of 0..15;
begin
  regs := type1_dcte^.disk_dinit;
  status := regs^.w_06;

  if 10 in status then
    type1_do_io^(type1_dcte^)
  else if status * [11, 12] <> [] then
    type0_do_io^(type0_dcte^)
  else
    crash_system(status_$disk_unrecognized_interrupt);
end;
