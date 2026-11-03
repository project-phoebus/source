{ smd_$is_valid_blt_ctl - check a BLT control longword.

  Image addresses:
    sau2  0x00E6FAA8  smd_$is_valid_blt_ctl (module-local)
    sau4  0x0F87A368  smd_$is_valid_blt_ctl (module-local)
    sau5  0x00E71F5E  smd_$is_valid_blt_ctl (module-local)

  - It accepts the four control longwords the driver takes.

  Status stored: none.
}

function smd_$is_valid_blt_ctl(ctl: linteger): boolean; internal;
begin
  smd_$is_valid_blt_ctl := (ctl = 16#02020020) or (ctl = 16#02020060)
                           or (ctl = 16#06060020)
                           or (ctl = 16#06060060);
end;
