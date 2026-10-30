{ MBUS_$UNDEF_INT - the handler of a Multibus interrupt level with none
  defined: crash.

  Image addresses:
    sau5  0x00E0AA0C  MBUS_$UNDEF_INT

  - CRASH_SYSTEM does not return, so the result false (not handled) is
    never reached; the argument is never read.

  Status stored: none.
}

function mbus_$undef_int(handler_arg: univ_ptr): boolean;
  options(val_param);
begin
  crash_system(status_$mbus_undefined_interrupt);
  mbus_$undef_int := false;
end;
