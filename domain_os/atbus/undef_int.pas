{ ATBUS_$UNDEF_INT - the handler of an AT bus interrupt with none
  defined: crash.

  Image addresses:
    sau9  0x3C40C758  ATBUS_$UNDEF_INT
    sau8  0x03C0B852  ATBUS_$UNDEF_INT

  - CRASH_SYSTEM does not return, so the result false (not handled) is
    never reached; the argument is never read.

  Status stored: none.
}

function atbus_$undef_int(handler_arg: univ_ptr): boolean;
  options(val_param);
begin
  crash_system(status_$atbus_undefined_interrupt);
  atbus_$undef_int := false;
end;
