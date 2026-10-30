{ TTY_$I_FLUSH_OUTPUT - discard all buffered output.

  Image addresses:
    sau2  0x00E1B806  TTY_$I_FLUSH_OUTPUT

  - TTY_$I_OUTPUT_BUFFER_DRAINED then wakes the writers.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure tty_$i_flush_output(in out tty: tty_$desc_t);
begin
  tty.output.tail := tty.output.head;
  tty_$i_output_buffer_drained(tty);
end;
