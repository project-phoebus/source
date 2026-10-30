{ ct_from_24 - a longword of a 24-bit value, its high byte cleared.

  Image addresses:
    sau9  0x3C477272  ct_from_24 (module-local)

  - The value goes through a ct_int24_t: its high byte cleared, the
    24-bit field stored, the longword read.

  Status stored: none.
}

function ct_from_24(v: integer32): integer32; internal;
var
  x: ct_int24_t;
begin
  x.f.hi := 0;
  x.f.lo := v;
  ct_from_24 := x.all;
end;
