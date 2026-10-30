{ tty_$i_set_dfl_funcs - bind or unbind the default function characters.

  Image addresses:
    sau2  0x00E6726E  tty_$i_set_dfl_funcs (module-local)

  - tty_$i_set_funcs over the slots enabled by default, this routine's
    static at .DATA +0x24: [0..16], [tty_$func_erase..tty_$func_replay].
  - Called from other code sections, it loads its own A5; tty/tty.pas
    has its `forward; internal' heading.

  Status stored: none.
}

procedure tty_$i_set_dfl_funcs(in out tty: tty_$desc_t; use_dfl: boolean);
  internal;
var
  { .DATA +0x24, 4 bytes }
  tty_$i_dfl_func_enable_mask: static tty_$func_set_t :=
    [tty_$func_erase..tty_$func_replay];    { [0..16] }
begin
  tty_$i_set_funcs(tty, tty_$i_dfl_func_enable_mask, use_dfl);
end;
