{ COLOR6_$BUSY_WAIT - wait until the board has taken its commands.

  Image addresses:
    sau7  0x3C48CAE2  COLOR6_$BUSY_WAIT

  - At the unit's page: with the control word's bit 12 set the FIFO is
    drained by waiting (color6_drain_fifo); otherwise its count is
    polled until zero, up to 8192 times.

  Status stored:
    status_$ok: the commands were taken, or the polls ran out
    color6_drain_fifo's status
}

[section(color6_wired_proc, wired_data)]
procedure color6_$busy_wait(dcte: color6_$dcte_ptr_t;
                            out status: status_$t);
  options(val_param);
var
  info: color6_$info_ptr_t;
  regs: color6_$regs_ptr_t;
  saved: color6_$byte_t;
  tries: integer;
  done: boolean;
begin
  status.all := status_$ok;
  info := dcte^.info;
  regs := info^.regs;
  saved := color6_get_page(regs);
  color6_set_page(info^.regs, dcte^.cnum);
  if 12 in regs^.ctl then
    color6_drain_fifo(dcte, status)
  else begin
    tries := 8192;
    repeat
      tries := tries - 1;
      done := color6_fifo_count(dcte) = 0;
    until done or (tries = 0);
  end;
  color6_set_page(info^.regs, saved);
end;
