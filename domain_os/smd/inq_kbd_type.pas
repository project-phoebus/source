{ SMD_$INQ_KBD_TYPE - the keyboard type string, through KBD.

  Image addresses:
    sau2  0x00E6E122  SMD_$INQ_KBD_TYPE
    sau5  0x00E70586  SMD_$INQ_KBD_TYPE
    sau9  0x3C474A68  SMD_$INQ_KBD_TYPE

  - Line 0's type string is copied as far as the caller's buffer holds.
  - A two-character type's second character is rewritten: `@' becomes a
    space and the length 1, anything else a lower-case letter.

  Status stored:
    kbd_$inq_kbd_type's status: the string was returned, or KBD failed
    smd_$invalid_buffer_size: the string is longer than buf_size
}

procedure smd_$inq_kbd_type(in buf_size: pinteger;
                            out buffer: univ smd_$string_t;
                            out length: pinteger;
                            out status: status_$t);
var
  buf: smd_$string_t;
  result_len: pinteger;
  i: integer;
begin
  kbd_$inq_kbd_type(0, buf, length, status);
  if status.all <> status_$ok then
    return;

  { as much as the caller's buffer holds }
  result_len := min(length, buf_size);
  for i := 1 to result_len do
    buffer[i] := buf[i];

  { the string did not fit }
  result_len := length;
  if result_len > buf_size then
    status.all := smd_$invalid_buffer_size;

  { a two-character type's second character }
  if result_len = 2 then
    if buffer[2] = '@' then begin
      length := 1;
      buffer[2] := ' ';
    end
    else
      buffer[2] := chr((ord(buffer[2]) & 16#1F) + 16#60);
end;
