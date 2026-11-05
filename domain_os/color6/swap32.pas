{ color6_swap32 - a longword with its bytes in the other order.

  Image addresses:
    sau7  0x3C4836D0  color6_swap32 (module-local)

  Status stored: none.
}

function color6_swap32(in l: univ color6_$bytes4_t): integer32; internal;
var
  r: record
    case integer of
      1: (l: integer32);
      2: (b: color6_$bytes4_t);
  end;
begin
  r.b[3] := l[0];
  r.b[2] := l[1];
  r.b[1] := l[2];
  r.b[0] := l[3];
  color6_swap32 := r.l;
end;
