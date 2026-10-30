{ VME_$UNDEF_INT - the handler of a VME vector with none defined: crash.

  Image addresses:
    sau5  0x00E0AA7C  VME_$UNDEF_INT

  - The system is crashed with status_$vme_undefined_interrupt; the
    result false (not handled) is never reached.  Every entry of
    VME_$INT_VEC and VME_$USER_VEC starts with it.

  Status stored: none.
}

function vme_$undef_int(handler_arg: univ_ptr): boolean;
  options(val_param);
begin
  crash_system(status_$vme_undefined_interrupt);
  vme_$undef_int := false;
end;
