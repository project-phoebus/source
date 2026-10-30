{ UNMAP_CASE - map a Domain/OS case-mapped pathname back to its Unix form.

  Image addresses:
    sau2  0x00E540D4  UNMAP_CASE
    sau9  0x3C45B5B0  UNMAP_CASE

  - MAP_CASE's inverse, a fragment for OLD_DIR's module (checked in the
    scratch module tmp/file/old_dir_check/old_dir.pas).
  - `\' becomes `../'; capitals become small letters; `:' and a byte
    decode the pair (a small letter a capital, a digit one of
    "!#%&+-?=@^", `_' a blank, `|' a backslash, `#' and hex digits a byte).
  - The output stops, the truncation flag left set, when it is full; a
    NUL follows if there is room.
  - A negative length stores a NUL; a final `:#' stores nothing; a non-hex
    digit counts as 0.

  Status stored: none.
}

procedure unmap_case(in name: univ name_$long_pname_t; in name_len: integer;
                     out output: univ name_$long_pname_t;
                     in max_out_len: integer; out out_len: integer;
                     out truncated: boolean);
var
  i: integer;
  ch: char;
  v: integer;
begin
  if name_len = 0 then begin
    truncated := false;
    out_len := 0;
  end
  else begin
    truncated := true;
    out_len := 1;
    i := 1;
    while i <= name_len do begin
      if out_len > max_out_len then
        return;
      ch := name[i];

      if ch = '\' then begin
        if (out_len > 1) and then (output[out_len - 1] <> '/') then begin
          output[out_len] := '/';
          out_len := out_len + 1;
        end;
        if out_len + 2 > max_out_len then
          return;
        output[out_len] := '.';
        output[out_len + 1] := '.';
        output[out_len + 2] := '/';
        out_len := out_len + 2;
      end

      else if ch in ['A'..'Z'] then
        output[out_len] := chr(ord(ch) + 16#20)

      else if ch <> ':' then
        output[out_len] := ch

      else if i = name_len then begin
        output[out_len] := ch;
        out_len := out_len + 1;
        exit;
      end

      { the escaped pair }
      else begin
        i := i + 1;
        ch := name[i];
        if ch in ['.', ':', 'A'..'Z', '`', '~'] then
          output[out_len] := ch
        else if ch in ['a'..'z'] then
          output[out_len] := chr(ord(ch) - 16#20)
        else if ch in ['0'..'9'] then
          case ch of
            '0': output[out_len] := '!';
            '1': output[out_len] := '#';
            '2': output[out_len] := '%';
            '3': output[out_len] := '&';
            '4': output[out_len] := '+';
            '5': output[out_len] := '-';
            '6': output[out_len] := '?';
            '7': output[out_len] := '=';
            '8': output[out_len] := '@';
            '9': output[out_len] := '^';
          end
        else
          case ch of
            '_': begin
              output[out_len] := ' ';
            end;
            '|': begin
              output[out_len] := '\';
            end;
            '$': begin
              output[out_len] := '$';
            end;
            '#': begin
              v := 0;
              if i < name_len then begin
                i := i + 1;
                if name[i] in ['0'..'9'] then
                  v := ord(name[i]) - 16#30
                else if name[i] in ['a'..'f'] then
                  v := ord(name[i]) - 16#61 + 10
                else if name[i] in ['A'..'F'] then
                  v := ord(name[i]) - 16#41 + 10;
                if i < name_len then begin
                  i := i + 1;
                  v := v * 16;
                  if name[i] in ['0'..'9'] then
                    v := v + ord(name[i]) - 16#30
                  else if name[i] in ['a'..'f'] then
                    v := v + ord(name[i]) - 16#61 + 10
                  else if name[i] in ['A'..'F'] then
                    v := v + ord(name[i]) - 16#41 + 10;
                end;
                output[out_len] := chr(v);
              end;
            end;
            otherwise begin
              output[out_len] := ch;
            end;
          end;
      end;

      i := i + 1;
      out_len := out_len + 1;
    end;

    out_len := out_len - 1;
    if out_len < max_out_len then
      output[out_len + 1] := chr(0);
    truncated := false;
  end;
end;
