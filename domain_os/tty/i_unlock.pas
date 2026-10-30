{ tty_$i_unlock - release the TTY lock.

  Image addresses:
    sau2  0x00E1AEE4  tty_$i_unlock (module-local)

  - ml_$term_lock, taken by tty_$i_lock; the descriptor argument is
    never read.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_unlock(var tty: tty_$desc_t); internal;
begin
  ml_$unlock(ml_$term_lock);
end;
