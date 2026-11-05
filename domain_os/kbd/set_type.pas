{ kbd_$set_type - install a keyboard type string and its translation table.

  Image addresses:
    sau2  0x00E1CA8C  kbd_$set_type (module-local)
    sau6  0x7801EA9C  kbd_$set_type (module-local)
    sau7  0x3C420D88  kbd_$set_type (module-local)

  - At most two characters are kept; the translation table is chosen by
    the caller's second character whatever the length,
    mnk_$ktt_ptrs[ord(ch) - 16#40], entry 0 when that is out of range.

  Status stored: none.
}

{ TODO(pascal) the signed test after the store: the field, compared in a register

  The test after the store of the length is a signed compare of the
  register that holds len, a pinteger the image compares unsigned four
  instructions before; `len < 2' would compare unsigned.  The body reads
  `kbd.kbd_type_len < 2' instead: the field is an integer (signed:
  KBD_$INQ_KBD_TYPE tests it signed), just stored from that register,
  and the compare uses the register that holds the value stored (a value
  reused after its store, as NETBUF_$GETVA does; not a known form for a
  field read back through a pointer). }

procedure kbd_$set_type(var kbd: kbd_$desc_t;
                        in type_str: univ kbd_$type_str_t;
                        type_len: pinteger); internal;
var
  len: pinteger;
  i: integer;
  idx: integer;
begin
  { at most two characters }
  len := type_len;
  if len > 2 then
    len := 2;

  for i := 0 to len - 1 do
    kbd.kbd_type_str[i] := type_str[i];

  kbd.kbd_type_len := len;
  if kbd.kbd_type_len < 2 then
    kbd.kbd_type_str[1] := chr(0);

  { the translation table, from the second character whatever the
    length }
  idx := ord(type_str[1]) - 16#40;
  if (idx < 0) or else (idx > mnk_$ktt_max) then
    idx := 0;
  kbd.ktt_ptr := mnk_$ktt_ptrs[idx];
end;
