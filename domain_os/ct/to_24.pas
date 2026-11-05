{ ct_to_24 - the low 24 bits of a longword, for a command's 24-bit field.

  Image addresses:
    sau7  0x3C484B38  ct_to_24 (module-local)
    sau9  0x3C47725C  ct_to_24 (module-local)

  - The value goes through a ct_int24_t: the longword stored, its 24-bit
    field read.

  Status stored: none.
}

function ct_to_24(v: integer32): integer32; internal;
var
  x: ct_int24_t;
begin
  x.all := v;
  ct_to_24 := x.f.lo;
end;
