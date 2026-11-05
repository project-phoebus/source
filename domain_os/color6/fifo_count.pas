{ color6_fifo_count - the number of words in the board's FIFO.

  Image addresses:
    sau7  0x3C48C9C2  color6_fifo_count (module-local)

  - Under the routine's spin lock: the control word's bits 3 and 4
    cleared, the two count-select words written, the count register
    read three times, the last read swapped.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
function color6_fifo_count(dcte: color6_$dcte_ptr_t): pinteger;
  internal;
var
  lock: static integer32 := 0;              { +0x0 }
  info: color6_$info_ptr_t;
  token: pinteger;
  regs: color6_$regs_ptr_t;
begin
  info := dcte^.info;
  lock := 0;
  token := ml_$spin_lock(lock);
  regs := info^.regs;
  regs^.ctl := regs^.ctl - [3, 4];
  regs^.word_318 := 0;
  regs^.word_31a := 16#1800;
  color6_fifo_count := regs^.fifo_count;
  color6_fifo_count := regs^.fifo_count;
  color6_fifo_count := color6_swap16(regs^.fifo_count);
  ml_$spin_unlock(lock, token);
end;
