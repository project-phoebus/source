{ TTY_$I_INIT - set up a line's descriptor.

  Image addresses:
    sau2  0x00E3324C  TTY_$I_INIT

  - The defaults: echo, CR to NL and strip on input; NL to CR-NL on
    output; BS erase, CRT erase and newline after kill; line mode, no
    process group, session 0, raw mode off.
  - The routine's statics are in OS_INIT_DATA (0x3C bytes):

      +0x00  signal_status, six statuses
      +0x18  signal_num, six words
      +0x24  pad_24, a longword (TODO below)
      +0x28  func_chars, 18 bytes, the default function characters
      +0x3A  2 bytes, the data section's padding to 4 bytes

  - Each signal entry pairs a status with a signal number in
    TTY_$I_SIGNAL's index order (QUIT, INT, TSTP, HUP, WINCH, CONT).

  Status stored: none.
}

{ TODO(pascal) OS_INIT_DATA +0x24's longword is unused (stand-in pad_24)

  The longword at OS_INIT_DATA +0x24 (zero) is read and written by
  nothing in the image.  It sits between the signal numbers and the
  function characters, so it is a static of this routine declared
  between them; pad_24 holds its place.  What the source declared there
  is not known (signal_num of eight elements, or a longword static of
  its own, give the same bytes). }

{ TODO(pascal) char_class loop: a scaled copy of a byte index

  The SAU2 image indexes the char_class word array with a scaled copy of
  the byte index, where the known form reaches wider elements through a
  stepped pointer; a byte (char) index is not a known form of it. }

[section(os_init_proc, os_init_data)]
procedure tty_$i_init(var tty: tty_$desc_t);
var
  { OS_INIT_DATA +0x00 }
  signal_status: static array[0..5] of status_$t := [
    [all := fault_$quit],                 { QUIT }
    [all := fault_$interrupt],            { INT }
    [all := fault_$suspend_proc_kbd],     { TSTP }
    [all := status_$hangup_fault],        { HUP }
    [all := status_$ok],                  { WINCH }
    [all := status_$ok]];                 { CONT }
  { OS_INIT_DATA +0x18 }
  signal_num: static array[0..5] of integer := [
    tty_$sig_quit, tty_$sig_int, tty_$sig_tstp,
    tty_$sig_hup, tty_$sig_winch, tty_$sig_cont];
  { OS_INIT_DATA +0x24: no reference (TODO above) }
  pad_24: static integer32 := 0;
  { OS_INIT_DATA +0x28 }
  func_chars: static array[tty_$func_erase..tty_$func_reserved_18] of char
    := [chr(8),                           { erase: BS }
        chr(16#17),                       { erase_word: ^W }
        chr(16#15),                       { kill: ^U }
        chr(4),                           { eof: ^D }
        chr(0),                           { eol: NUL }
        chr(9),                           { tab: HT }
        chr(13),                          { cr: CR }
        chr(10),                          { nl: LF }
        chr(16#1C),                       { quit: ^\ }
        chr(3),                           { int: ^C }
        chr(16#1A),                       { susp: ^Z }
        chr(16#19),                       { dsusp: ^Y }
        chr(16#16),                       { quote: ^V }
        chr(16#13),                       { stop: ^S }
        chr(16#11),                       { start: ^Q }
        chr(16#0F),                       { oflush: ^O }
        chr(16#12),                       { replay: ^R }
        chr(0)];                          { reserved_18: NUL }
  f: tty_$func_t;
  ch: char;
  i: integer;
begin
  { flags, crash character }
  tty.state_flags := [];
  tty.input_flags := [tty_$if_echo, tty_$if_cr_to_nl, tty_$if_strip];
  tty.output_flags := [tty_$of_nl_to_crnl];
  tty.echo_flags := [tty_$echo_bs_erase, tty_$echo_crt_erase,
                     tty_$echo_kill_nl];
  tty.raw_saved_input_flags := [];
  tty.raw_saved_output_flags := [];
  tty.crash_char := chr(0);

  { the default function characters }
  for f := tty_$func_erase to tty_$func_reserved_18 do
    tty.func_chars[f] := func_chars[f];

  tty.func_enabled := [tty_$func_erase..tty_$func_eof,
                       tty_$func_tab..tty_$func_replay];

  { every character ordinary }
  for ch := chr(0) to chr(255) do
    tty.char_class[ch] := tty_$class_normal;

  { line mode, no process group }
  tty.break_mode.break_type := tty_$break_on_eol;
  tty.pgroup_uid := uid_$nil;
  tty.session_id := 0;
  tty.column := 0;
  tty.saved_input_flags := 0;
  tty.pending_signal := [];

  tty_$i_set_dfl_funcs(tty, true);
  tty.raw_mode := false;

  { the signal entries }
  for i := 0 to 5 do begin
    tty.signals[i].tty_desc := addr(tty);
    tty.signals[i].fault_status := signal_status[i];
    tty.signals[i].signal_num := signal_num[i];
  end;

  { both buffers empty }
  tty.input_head := 1;
  tty.input.head := 1;
  tty.input.tail := 1;
  tty.input.size := tty_$buf_size;
  tty.output.head := 1;
  tty.output.tail := 1;
  tty.output.size := tty_$buf_size;
end;
