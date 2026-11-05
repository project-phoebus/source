{ SYSBUS_$UNDEF_INT - the handler of a system bus level with none
  defined: crash.

  Image addresses:
    sau4  0x0F80B330  SYSBUS_$UNDEF_INT
    sau6  0x7800B4BC  SYSBUS_$UNDEF_INT
    sau9  0x3C40C4EC  SYSBUS_$UNDEF_INT

  - CRASH_SYSTEM does not return, so the result false (not handled) is
    never reached; the argument is never read.
  - A fragment of the ATBUS_ module (sysbus/atbus_.pas), with
    `sysbus_int_vec'.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function sysbus_$undef_int(handler_arg: univ_ptr): boolean;
  options(val_param);
begin
  crash_system(status_$sysbus_undefined_interrupt);
  sysbus_$undef_int := false;
end;
