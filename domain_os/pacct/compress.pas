{ pacct_$compress - a longword as an accounting "comp_t": a 13-bit
  mantissa and a 3-bit base-8 exponent.

  Image addresses:
    sau2  0x00E5A9CA  pacct_$compress (module-local)

  - The value is shifted right by 3 while it does not fit in 13 bits,
    and rounded up when the last bit shifted out from position 2 was
    set (shifted once more if that overflows).
  - The exponent goes in the word's top 3 bits, the value in the low 13.

  Status stored: none.
}

{ TODO(pascal) the rounding bit is a bit test of the held value

  round_up is set from a test of bit 2 of the register-held value, a
  bit test of an integer as a boolean value.  Read as `(value & 4) <>
  0', the reading suma/rcv.pas's TODO takes for its bit-6 test; `&' with
  a constant compiles as a load of the constant and an `and', and a bit
  test on a register is a set's member test (`2 in s'), which an integer
  is not.  Not a known form. }

function pacct_$compress(value: linteger): comp_t; internal;
type
  comp_rec_t = packed record
    case integer of
      1: (exp: 0..7;                      { bits 15..13 }
          mantissa: 0..8191);             { bits 12..0 }
      2: (word: comp_t);
  end;
var
  round_up: boolean;
  comp: comp_rec_t;
  exp: integer;
begin
  exp := 0;
  round_up := false;
  while value >= 16#2000 do begin
    exp := exp + 1;
    round_up := (value & 4) <> 0;
    value := rshft(value, 3);
  end;
  if round_up then begin
    value := value + 1;
    if value >= 16#2000 then begin
      exp := exp + 1;
      value := rshft(value, 3);
    end;
  end;

  comp.exp := exp;
  comp.mantissa := value;
  pacct_$compress := comp.word;
end;
