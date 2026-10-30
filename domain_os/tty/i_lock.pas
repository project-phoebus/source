{ tty_$i_lock - take the TTY lock.

  Image addresses:
    sau2  0x00E1AED0  tty_$i_lock

  - ml_$term_lock, the lock of the whole TTY subsystem; the descriptor
    argument is never read.
  - Called from the default section too: the three TTY code segments
    are one compilation unit (tty/tty.pas), since an internal routine
    can only be called from its own unit.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_lock(var tty: tty_$desc_t); internal;
begin
  ml_$lock(ml_$term_lock);
end;
