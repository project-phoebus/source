{ VFMT_$MAIN - format a control string and its arguments into a buffer.

  Image addresses:
    sau2  0x00E6AB2A  VFMT_$MAIN
    sau2  0x00E6A9F6  vfmt_output_char (nested)
    sau2  0x00E6AA38  vfmt_get_next_arg (nested)
    sau2  0x00E6AA4C  vfmt_parse_number (nested)
    sau2  0x00E6AAB6  vfmt_parse_number_after_m (nested)

  - The control string is copied to the text, at most text_capacity
    characters, each `%' directive's modifiers (up to ten) read up to
    its letter.
  - D H O a number; A a string (its address and length the next
    arguments, unless M<n>); T a tab; X blanks; ( ) a repeat group; % a
    percent; / a newline; . a newline and the end; $ the end.
  - Too many modifiers, or 200 characters of control string, end the
    text with "??"; the text is as long as the furthest tab.

  Status stored: none.
}

{ TODO(pascal) VFMT_$MAIN's three pointers into args

  The SAU2 image reaches args[arg_count] and args[arg_count - 1]
  through three pointers kept in step with arg_count, not through
  arg_count: one for `addr(args[arg_count])', one for the element's
  value (its post-increment doing that part's step) and a frame
  temporary for `addr(args[arg_count - 1])', each formed from args'
  address before the loop and stepped wherever arg_count is, while
  arg_count itself is still kept in memory and never read.  This is
  strength reduction of a variable that is not a `for' index, in a
  `while' loop (ref 6.4.24, p. 6-29, lists "Strength reduction" and
  "induction variable" optimizations at -opt 3), with the third pointer
  spilled because every callee-saved register is in use.  Stepped
  pointers are otherwise seen for `for' loops only; dpc indexes args by
  arg_count.  The Pascal is the plain indexing; the stand-in unused_48
  keeps the frame's size. }

{ TODO(pascal) variables passed by address but held in registers

  Several of VFMT_$MAIN's variables whose addresses are passed are held
  in registers between those uses in the SAU2 image: width (in the A
  and T arms), len, x_count, ch (formed in a register and stored to its
  slot only for the call) and len_p (likewise).  VFMT_$WRITE does the
  same with its len (vfmt/write.pas), and there the frame has no room
  for a second variable, so this reading is used here too: one variable
  each.  The other reading, separate register-held locals copied to and
  from the frame variables (`ch := c2', `col := width'), fits this
  routine's frame (it has unaddressed bytes) and dpc's rule (which keeps
  a variable whose address is passed in the frame); it would not fit
  VFMT_$WRITE's. }

{ TODO(pascal) the nested routines' `in' characters by address

  vfmt_output_char takes its character by address, and VFMT_$MAIN
  passes it constant cells as well as variables: so an `in' parameter
  by address.  dpc gives nested routines `internal''s convention
  (applied there on the evidence of nested routines taking words by
  value), under which an `in' char is passed by value; `univ' cancels
  that (ref 5.2, Table 5-1), so the parameter is `in ch: univ char', as
  vfmt_get_next_arg's is `in cell: univ vfmt_$view_ptr_t' (by address).
  The reference does not say what convention a nested routine gets; if
  it is the default one (by address unless `val_param'), plain
  `in ch: char' gives the same code and the `univ' is not the
  original's. }

procedure vfmt_$main(in control_string: univ vfmt_$string_t;
                     out text: univ vfmt_$string_t;
                     in text_capacity: integer;
                     out text_length: integer;
                     in args: vfmt_$arg_ptr_t);
var
  done: boolean;
  c: char;                                { the directive letter }
  keep_blanks: boolean;                   { the Z modifier }
  spec: vfmt_$spec_t;                     { the modifier string }
  str: vfmt_$view_ptr_t;
  i: integer;
  j: integer;                             { the blank loops' index, not
                                            read }
  len_p: vfmt_$view_ptr_t;
  repeat_pos: integer;
  repeat_count: integer;
  max_written: integer;                   { the furthest column a tab
                                            reached }
  width: integer;
  len: integer;
  k: integer;
  blanks: integer;
  num_len: integer;
  pos: integer;
  spec_len: integer;
  arg_count: integer;
  x_count: integer;
  unused_38: integer32;                   { stand-in }
  ch: char;
  unused_3c: integer;                     { stand-in }
  lowercase: boolean;
  uppercase: boolean;
  unused_44: integer32;                   { stand-in }
  unused_48: integer32;                   { the compiler's pointer
                                            temporary, see the TODO on
                                            args }

  { vfmt_output_char - append one character to the text.

    - The character goes after the last one when text_length is below
      text_capacity; else it is dropped.
    - Nested in VFMT_$MAIN, whose frame it reaches.

    Status stored: none. }

  procedure vfmt_output_char(in ch: univ char);
  begin
    if text_length < text_capacity then begin
      text_length := text_length + 1;
      text[text_length] := ch;
    end;
  end;

  { vfmt_get_next_arg - the pointer a cell holds.

    - The longword the argument's address holds, a pointer to an
      argument's characters or length words.
    - Nested in VFMT_$MAIN, but it reaches no enclosing frame.

    Status stored: none. }

  function vfmt_get_next_arg(in cell: univ vfmt_$view_ptr_t):
    vfmt_$view_ptr_t;
  begin
    vfmt_get_next_arg := cell;
  end;

  { vfmt_parse_number - the number in the modifier string.

    - The decimal digits of the modifier string up to its first M, other
      characters skipped; -1 when there are none.
    - Nested in VFMT_$MAIN, whose frame it reaches.

    Status stored: none. }

  procedure vfmt_parse_number(out n: integer);
  var
    c: char;
    i: integer;
    unused_a: integer;                    { stand-in }
  begin
    n := -1;

    for i := 1 to spec_len do begin
      c := spec[i];
      if c = 'M' then exit;
      if (c >= '0') and then (c <= '9') then
        if n = -1 then
          n := ord(c) - ord('0')
        else
          n := n * 10 + ord(c) - ord('0');
    end;
  end;

  { vfmt_parse_number_after_m - the number after the M in the modifier
    string.

    - The decimal digits after an M; -1 when there are none.
    - Nested in VFMT_$MAIN, whose frame it reaches.

    Status stored: none. }

  procedure vfmt_parse_number_after_m(out n: integer);
  var
    seen: boolean;
    c: char;
    i: integer;
  begin
    n := -1;
    seen := false;

    for i := 1 to spec_len do begin
      c := spec[i];
      if c = 'M' then
        seen := true
      else if ((c >= '0') and seen) and then (c <= '9') then
        if n = -1 then
          n := ord(c) - ord('0')
        else
          n := n * 10 + ord(c) - ord('0');
    end;
  end;

begin
  arg_count := 0;
  pos := 0;
  text_length := 0;
  max_written := 0;
  repeat_count := 0;

  while pos < 200 do begin
    pos := pos + 1;
    if control_string[pos] <> '%' then
      vfmt_output_char(control_string[pos])
    else begin
      { the modifier string, up to and with the directive letter, blanks
        skipped }
      spec_len := 0;
      done := false;
      while not done do begin
        pos := pos + 1;
        c := control_string[pos];
        if (c >= 'a') and then (c <= 'z') then
          c := chr(ord(c) - 32);
        if (c = '%') or else (c = 'T') or else (c = 'A') or else
           (c = ')') or else (c = '(') or else (c = 'X') or else
           (c = 'H') or else (c = 'D') or else (c = 'O') or else
           (c = '/') or else (c = '.') or else (c = '$') then
          done := true;
        if c <> ' ' then begin
          spec_len := spec_len + 1;
          if spec_len > 10 then exit;
          spec[spec_len] := c;
        end;
      end;

      if spec_len > 10 then exit;

      if (c = '.') or else (c = '/') then
        vfmt_output_char(chr(10));

      if (c = '.') or else (c = '$') then begin
        if max_written > text_length then
          text_length := max_written;
        return;
      end;

      if (c = 'H') or else (c = 'O') or else (c = 'D') then begin
        { a number }
        if spec_len < 10 then begin
          spec_len := spec_len + 1;
          spec[spec_len] := ' ';
        end;
        text_length := text_length + 1;
        arg_count := arg_count + 1;
        vfmt_format_number(spec, args[arg_count]^, text[text_length],
                           text_capacity - text_length + 1, num_len);
        text_length := text_length + num_len - 1;
      end

      else if c = 'A' then begin
        { the string's address and length }
        vfmt_parse_number(width);
        vfmt_parse_number_after_m(len);
        if len < 0 then begin
          arg_count := arg_count + 2;
          len_p := vfmt_get_next_arg(args[arg_count]);
          if len_p^.w > 0 then
            len := len_p^.w
          else
            len := vfmt_get_next_arg(len_p)^.lo;
          str := vfmt_get_next_arg(args[arg_count - 1]);
        end
        else begin
          arg_count := arg_count + 1;
          str := vfmt_get_next_arg(args[arg_count]);
        end;
        if (width >= 0) and then (len > width) then
          len := width;

        { Z, L and U }
        keep_blanks := false;
        uppercase := false;
        lowercase := false;
        for i := 1 to spec_len do
          if spec[i] = 'Z' then
            keep_blanks := true
          else if spec[i] = 'L' then
            lowercase := true
          else if spec[i] = 'U' then
            uppercase := true;

        if keep_blanks or else (width >= 0) then begin
          { every character, then the padding }
          for i := 1 to len do begin
            ch := str^.chars[i];
            if uppercase then begin
              if (ch >= 'a') and then (ch <= 'z') then
                ch := chr(ord(ch) - 32);
            end
            else if lowercase then begin
              if (ch >= 'A') and then (ch <= 'Z') then
                ch := chr(ord(ch) + 32);
            end;
            vfmt_output_char(ch);
          end;
          if width > len then
            for j := 1 to width - len do
              vfmt_output_char(' ');            { merged with X's }
        end
        else begin
          { blanks only before a non-blank }
          blanks := 0;
          for i := 1 to len do
            if (str^.chars[i] = ' ') or else
               (ord(str^.chars[i]) = 160) then
              blanks := blanks + 1
            else begin
              if blanks > 0 then
                for j := 1 to blanks do
                  vfmt_output_char(' ');
              blanks := 0;
              ch := str^.chars[i];
              if uppercase then begin
                if (ch >= 'a') and then (ch <= 'z') then
                  ch := chr(ord(ch) - 32);
              end
              else if lowercase then begin
                if (ch >= 'A') and then (ch <= 'Z') then
                  ch := chr(ord(ch) + 32);
              end;
              vfmt_output_char(ch);
            end;
        end;
      end

      else if c = '(' then begin
        vfmt_parse_number(repeat_count);
        if repeat_count < 1 then
          repeat_count := 1;
        repeat_count := repeat_count - 1;
        repeat_pos := pos;
      end

      else if c = ')' then begin
        if repeat_count > 0 then begin
          repeat_count := repeat_count - 1;
          pos := repeat_pos;
        end;
      end

      else if c = '%' then
        vfmt_output_char('%')

      else if c = 'T' then begin
        { the column }
        vfmt_parse_number(width);
        if width < 0 then begin
          arg_count := arg_count + 1;
          len_p := vfmt_get_next_arg(args[arg_count]);
          if len_p^.w > 0 then
            width := len_p^.w
          else
            width := vfmt_get_next_arg(len_p)^.lo;
        end;

        if (width <= 0) or else (width >= 1024) then
          width := text_length + 1;

        if text_length > max_written then
          max_written := text_length;

        { blanks up to the column, no capacity check }
        if width > max_written then
          for k := max_written + 1 to width - 1 do
            text[k] := ' ';

        text_length := width - 1;
      end

      else if c = 'X' then begin
        { at least one blank }
        vfmt_parse_number(x_count);
        if x_count < 1 then
          x_count := 1;
        for j := 1 to x_count do
          vfmt_output_char(' ');
      end;
    end;
  end;

  { an unterminated or bad directive }
  vfmt_output_char('?');
  vfmt_output_char('?');
end;
