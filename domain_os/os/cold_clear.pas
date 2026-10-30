{ cold_clear - clear a table before the MMU is on.

  Image addresses:
    sau9  0x04003068  cold_clear (module-local)

  - p is the table's physical address, len its length in bytes; the
    loop clears the longwords 0 .. len div 4.

  Status stored: none.
}

procedure cold_clear(p: integer32; len: linteger); internal;
var
  q: os_cold_table_ptr_t;
  n: linteger;
  i: linteger;
begin
  q := os_cold_table_ptr_t(p);
  n := len div 4;
  for i := 0 to n do
    q^[i] := 0;
end;
