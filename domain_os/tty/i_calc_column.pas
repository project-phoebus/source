{ tty_$i_calc_column - the display column reached by echoing part of the
  input buffer.

  Image addresses:
    sau2  0x00E1B4B6  tty_$i_calc_column

  - From position start to the producer position, from column: TAB
    moves to the next multiple of 8, BS back one (not past 0), CR to 0;
    a control character or DEL takes two columns under
    tty_$echo_cntl_with_hat, else none; any other character one.

  Status stored: none.
}

{ TODO(pascal) 8 unexplained frame bytes (stand-in unused_10)

  The SAU2 frame holds 8 bytes more than the locals and the word result
  variable account for; the stand-in unused_10 takes them as a longword
  after ch (an 8-byte array of words would fill the same bytes).
  Rejected readings: frame copies of the value parameters
  (tty_$i_break_char's by-value ch gets none), pos and tail as
  longwords, a longword result variable, a hidden slot for the `while'
  loop. }

[section(wired_proc, wired_data)]
function tty_$i_calc_column(in buf: tty_$cbuf_t; start: tty_$buf_pos_t;
                            column: tty_$uword_t;
                            echo_flags: tty_$echo_flag_set_t): tty_$uword_t;
  internal;
var
  pos: tty_$buf_pos_t;
  tail: tty_$buf_pos_t;
  ch: char;
  unused_10: integer32;                   { stand-in, see TODO }
begin
  pos := start;
  tail := buf.tail;

  { one character per pass }
  while pos <> tail do begin
    ch := buf.data[pos];
    if ch = chr(9) then
      column := (column + 7) div 8 * 8
    else if ch = chr(8) then begin
      if column <> 0 then
        column := column - 1;
    end
    else if ch = chr(13) then
      column := 0
    else if (ch < ' ') or else (ch = chr(127)) then begin
      if tty_$echo_cntl_with_hat in echo_flags then
        column := column + 2;
    end
    else
      column := column + 1;

    { the next position, 256 wraps to 1 }
    if pos = tty_$buf_size then
      pos := 1
    else
      pos := pos + 1;
  end;

  tty_$i_calc_column := column;
end;
