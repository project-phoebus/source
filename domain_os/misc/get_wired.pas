{ GET_WIRED - the address of the AUDIT module's wired block.

  Image addresses:
    sau2  0x00E1D8DC  GET_WIRED

  - The result is its static's address, the eventcount and exclusion
    lock of the map's AUDIT data segment in WIRED_DATA (32 bytes, zero),
    which AUDIT_$INIT keeps.  Headed `[section(wired_proc, wired_data)]'.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function get_wired: univ_ptr;
type
  audit_$wired_t = record
    ec: ec_$eventcount_t;                 { 0x00 }
    lock: ml_$exclusion_t;                { 0x0C }
  end;
var
  wired: static audit_$wired_t;           { zero }
begin
  get_wired := addr(wired);
end;
