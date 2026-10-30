{ TTY_$I_OUTPUT_BUFFER_DRAINED - the output buffer has drained: wake the
  writers.

  Image addresses:
    sau2  0x00E1B394  TTY_$I_OUTPUT_BUFFER_DRAINED

  - A driver calls it through a table OS_TERM_INIT fills, when its
    output has gone.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_output_buffer_drained(in out tty: tty_$desc_t);
begin
  tty.state_flags := tty.state_flags - [tty_$st_output_wait];
  tty_$i_advance_ec(tty.output_ec^);
end;
