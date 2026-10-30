{ TTY_$I_SIGNAL - queue a signal for the line's process group.

  Image addresses:
    sau2  0x00E1B824  TTY_$I_SIGNAL

  - The signal's entry (QUIT, INT, TSTP, HUP, WINCH or CONT; any other
    signal does nothing) is queued with TTY_$I_DXM_SIGNAL on DXM's
    unwired queue, to be sent from the DXM helper process.
  - A duplicate of a queued callback is not queued again.
  - DXM_$ADD_CALLBACK's status is ignored.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_signal(var tty: tty_$desc_t; signal: integer);
  options(val_param);
var
  status: status_$t;
  signal_index: integer;
begin
  { the entry of the signal }
  case signal of
    tty_$sig_quit:  signal_index := 0;
    tty_$sig_int:   signal_index := 1;
    tty_$sig_tstp:  signal_index := 2;
    tty_$sig_hup:   signal_index := 3;
    tty_$sig_winch: signal_index := 4;
    tty_$sig_cont:  signal_index := 5;
    otherwise
      return;
  end;

  { queue the callback with a copy of the entry }
  dxm_$add_callback(dxm_$unwired_q, addr(tty_$i_dxm_signal),
                    addr(tty.signals[signal_index]), 12, true, status);
end;
