{ color6_swap16 - a word with its bytes in the other order.

  Image addresses:
    sau7  0x3C48C91E  color6_swap16 (module-local)

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
function color6_swap16(in w: univ color6_$bytes2_t): pinteger;
var
  r: record
    case integer of
      1: (w: pinteger);
      2: (b: color6_$bytes2_t);
  end;
begin
  r.b[1] := w[0];
  r.b[0] := w[1];
  color6_swap16 := r.w;
end;
