{ MAP_CASE - map a Unix-style pathname to its Domain/OS case-mapped form.

  Image addresses:
    sau2  0x00E53EF8  MAP_CASE

  - A fragment for OLD_DIR's module, checked in the scratch module
    tmp/file/old_dir_check/old_dir.pas.
  - Each byte is mapped: `.', `` ` '' and `~' starting a component (but
    `.' and `..' names) and capitals get a `:' before them; small
    letters become capitals.
  - Control and high bytes become `:#' and two hex digits; `:' `::',
    blank `:_', backslash `:|'.
  - The truncation flag is left set when the output fills.
  - Capitals are escaped without a room check; 10..15 of the high nibble
    come out as `:'..`?'.

  Status stored: none.
}

{ TODO(pascal) MAP_CASE's 4 unexplained frame bytes

  Nothing in the frame is addressed: i, comp_start, the `for' loop's
  count and ch, all register-held, give 8 bytes if each keeps a word's
  slot; the other 4 bytes are not explained (a
  global: no reserved slot). }

procedure map_case(in name: univ name_$long_pname_t; in name_len: integer;
                   out output: univ name_$long_pname_t;
                   in max_out_len: integer; out out_len: integer;
                   out truncated: boolean);
var
  i: integer;
  comp_start: integer;
  ch: char;
begin
  out_len := 0;

  if name_len > 0 then begin
    comp_start := 1;
    truncated := true;
    for i := comp_start to name_len do begin
      if out_len >= max_out_len then
        return;
      ch := name[i];

      { a component's first byte }
      if i = comp_start then
        case ch of
          '`', '.', '~': begin
            if ch = '.' then
              if (i = name_len) or else (name[i + 1] = '/') then begin
                out_len := out_len + 1;
                output[out_len] := '.';
                next;
              end
              else if name[i + 1] = '.' then
                if (i + 1 = name_len) or else (name[i + 2] = '/') then begin
                  out_len := out_len + 1;
                  output[out_len] := ch;
                  next;
                end;
            if out_len + 2 > max_out_len then
              return;
            out_len := out_len + 2;
            output[out_len - 1] := ':';
            output[out_len] := ch;
            next;
          end;
        end;

      if (ch >= 'A') and then (ch <= 'Z') then begin
        out_len := out_len + 2;
        output[out_len - 1] := ':';
        output[out_len] := ch;
      end
      else if (ch >= 'a') and then (ch <= 'z') then begin
        out_len := out_len + 1;
        output[out_len] := chr(ord(ch) - 16#20);
      end
      else if ((ch >= chr(1)) and (ch <= chr(16#1F))) or else
              ((ch >= chr(16#7F)) and then (ch <= chr(16#FF))) then begin
        if out_len + 4 > max_out_len then
          return;
        out_len := out_len + 4;
        output[out_len - 3] := ':';
        output[out_len - 2] := '#';
        output[out_len - 1] := chr(rshft(ord(ch), 4) + 16#30);
        if (ord(ch) & 16#F) <= 9 then
          output[out_len] := chr((ord(ch) & 16#F) + 16#30)
        else
          output[out_len] := chr((ord(ch) & 16#F) + 16#57);
      end
      else
        case ch of
          ':': begin
            if out_len + 2 > max_out_len then
              return;
            out_len := out_len + 2;
            output[out_len - 1] := ':';
            output[out_len] := ch;
          end;
          ' ': begin
            if out_len + 2 > max_out_len then
              return;
            out_len := out_len + 2;
            output[out_len - 1] := ':';
            output[out_len] := '_';
          end;
          '\': begin
            if out_len + 2 > max_out_len then
              return;
            out_len := out_len + 2;
            output[out_len - 1] := ':';
            output[out_len] := '|';
          end;
          otherwise begin
            out_len := out_len + 1;
            output[out_len] := ch;
            if ch = '/' then
              comp_start := i + 1;
          end;
        end;
    end;
  end;

  truncated := false;
end;
