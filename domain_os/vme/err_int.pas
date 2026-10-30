{ VME_$ERR_INT - the VME bus error interrupt routine.

  Image addresses:
    sau5  0x00E0AC7A  VME_$ERR_INT

  - The bus state is saved (VME_$SAVE_VME).  Bit 14 of the saved word_60
    crashes the system with status_$vme_bus_error; else 16#60 is written
    into the adapter's word at 0x40 (what that does is not known).
  - The result is true.

  Status stored: none.
}

function vme_$err_int: boolean;
begin
  vme_$save_vme;
  if (vme_$save.word_60 & 16#4000) <> 0 then
    crash_system(status_$vme_bus_error)
  else
    vme_ctl.word_40 := 16#60;
  vme_$err_int := true;
end;
