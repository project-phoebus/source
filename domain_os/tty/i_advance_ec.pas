{ tty_$i_advance_ec - advance a TTY eventcount without a dispatch.

  Image addresses:
    sau2  0x00E1AEF8  tty_$i_advance_ec

  - EC_$ADVANCE_WITHOUT_DISPATCH wakes the waiters but does not enter
    the dispatcher: the TTY code runs at interrupt level.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_advance_ec(var ec: ec_$eventcount_t); internal;
begin
  ec_$advance_without_dispatch(ec);
end;
