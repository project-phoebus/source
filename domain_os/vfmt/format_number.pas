{ vfmt_format_number - render one number into a field of characters.

  Image addresses:
    sau2  0x00E6A704  vfmt_format_number

  - Up to ten modifiers: S, U, P sign modes; O, D, H bases; Z leading
    zeros; W word, L longword; R, J justification; digits a width; a
    blank ends them, any other character makes the result '?'.
  - The value is converted to twenty digits and a field of at least the
    number's width copied out, no more than max_len, counted in out_len.
  - Module-local (no map symbol), the segment's first routine.

  Status stored: none.
}

procedure vfmt_format_number(in spec: univ vfmt_$spec0_t;
                             in value: univ vfmt_$value_t;
                             out output: univ vfmt_$out0_t;
                             max_len: integer;
                             out out_len: integer); internal;
var
  digits: array[0..19] of char;
  v: linteger;
  width: integer;
  count: pinteger;
  start: pinteger;
  sign_pos: integer;
  negative: boolean;
  c: char;
  k: integer;
  i: integer;
  size: integer;                          { 1 longword, 0 word }
  j: integer;
  base: integer;
  sign_mode: integer;                     { 0 unsigned, 1 signed, 2
                                            signed with '+' }
  unused_38: integer32;                   { stand-in }
  strip: boolean;
  bad: boolean;
  right: boolean;
  unused_40: integer;                     { stand-in }
  unused_44: integer32;                   { stand-in }
begin
  base := 10;
  sign_mode := 0;
  width := -1;
  size := 1;
  strip := true;
  bad := false;
  right := true;

  { the modifier characters }
  for k := 0 to 9 do begin
    c := spec[k];
    if (c >= 'a') and then (c <= 'z') then
      c := chr(ord(c) - 32);
    case c of
      ' ': exit;
      'S': sign_mode := 1;
      'U': sign_mode := 0;
      'P': sign_mode := 2;
      'O': base := 8;
      'D': base := 10;
      'H': base := 16;
      'Z': strip := false;
      'W': size := 0;
      'L': size := 1;
      'R': right := true;
      'J': right := false;
      '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
        if width = -1 then
          width := ord(c) - ord('0')
        else
          width := width * 10 + ord(c) - ord('0');
      otherwise
        bad := true;
    end;
  end;

  if bad then begin
    output[0] := '?';
    out_len := 1;
    return;
  end;

  { the value and its magnitude }
  negative := false;
  case size of
    0: begin
      if sign_mode <> 0 then
        if value.w < 0 then begin
          v := -value.w;
          negative := true;
        end
        else
          v := value.w
      else
        v := value.uw;
    end;
    1: begin
      v := value.l;
      if sign_mode <> 0 then
        if value.l < 0 then begin
          v := -value.l;
          negative := true;
        end
        else
          v := value.l;
    end;
  end;

  { twenty digits, the last first }
  for i := 19 downto 0 do begin
    digits[i] := chr(v mod base + ord('0'));
    if digits[i] > '9' then
      digits[i] := chr(ord(digits[i]) + 7);
    v := v div base;
  end;

  { the leading zeros, blanked unless Z; at least one digit stays }
  count := 20;
  for i := 0 to 18 do begin
    if digits[i] <> '0' then exit;
    if strip then
      digits[i] := ' ';
    count := count - 1;
  end;

  { the sign }
  if negative or else (sign_mode = 2) then begin
    count := count + 1;
    if strip or else (width <= count) then
      sign_pos := 20 - count
    else
      sign_pos := 20 - width;
    if negative then
      digits[sign_pos] := '-'
    else
      digits[sign_pos] := '+';
  end;

  { the field is at least the number's width }
  if count > width then
    width := count;

  { blank the field }
  for i := 0 to width - 1 do
    if i < max_len then
      output[i] := ' ';

  { where the field starts in the digits }
  out_len := 0;
  if ((not strip) or right) or else (width <= count) then
    start := 19 - width
  else
    start := 19 - count;

  { the field, blanks outside the digits }
  for j := 1 to width do begin
    if out_len >= max_len then return;
    if (j + start > 19) or else (j + start < 0) then
      output[out_len] := ' '
    else
      output[out_len] := digits[j + start];
    out_len := out_len + 1;
  end;
end;
