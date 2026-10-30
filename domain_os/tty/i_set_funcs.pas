{ tty_$i_set_funcs - bind or unbind a set of function characters.

  Image addresses:
    sau2  0x00E6720E  tty_$i_set_funcs (module-local)

  - Each slot in funcs gets its function's class when use_dfl is true
    and the slot is enabled, else it is made ordinary.
  - The class table is this routine's static, .DATA +0x00..+0x23: 18
    words, one per slot.

  Status stored: none.
}

{ TODO(pascal) the slots' classes disagree with some of the class names

  The classes the image binds to the slots disagree with some of the
  class names (tty/tty.ins.pas, "Character classes"): the eof slot gets
  16#0C (tty_$class_discard), dsusp 3 (tty_$class_break), quote 4
  (tty_$class_eof), eol 16#0B (tty_$class_nl), cr 16#0F
  (tty_$class_crlf), nl 16#0E (tty_$class_cr).  TTY_$K_GET ends input as
  end of file at class 16#0C and signals tty_$sig_tstp at class 3
  (tty/k_get.pas), which fits the slots, not the names.  The values are
  the image's; the names are kept until the classes are renamed.  The
  reserved slot's 0 is written as 0, not as tty_$class_sigint. }

procedure tty_$i_set_funcs(in out tty: tty_$desc_t; funcs: tty_$func_set_t;
                           use_dfl: boolean); internal;
var
  { .DATA +0x00, 18 words }
  tty_$i_dfl_func_classes: static
    array[tty_$func_erase..tty_$func_reserved_18] of integer := [
      tty_$class_del,                     { erase }
      tty_$class_werase,                  { erase_word }
      tty_$class_kill,                    { kill }
      tty_$class_discard,                 { eof: 16#0C, see TODO }
      tty_$class_nl,                      { eol: 16#0B }
      tty_$class_tab,                     { tab }
      tty_$class_crlf,                    { cr: 16#0F }
      tty_$class_cr,                      { nl: 16#0E }
      tty_$class_sigquit,                 { quit }
      tty_$class_sigint,                  { int }
      tty_$class_sigtstp,                 { susp }
      tty_$class_break,                   { dsusp: 3 }
      tty_$class_eof,                     { quote: 4 }
      tty_$class_xoff,                    { stop }
      tty_$class_xon,                     { start }
      tty_$class_flushout,                { oflush }
      tty_$class_reprint,                 { replay }
      0];                                 { reserved_18 }
  f: tty_$func_t;
begin
  for f := tty_$func_erase to tty_$func_reserved_18 do
    if f in funcs then
      if use_dfl and then (f in tty.func_enabled) then
        tty.char_class[tty.func_chars[f]] := tty_$i_dfl_func_classes[f]
      else
        tty.char_class[tty.func_chars[f]] := tty_$class_normal;
end;
