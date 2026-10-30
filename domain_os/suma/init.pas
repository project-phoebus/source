{ SUMA_$INIT - initialize the bitpad driver's state.

  Image addresses:
    sau2  0x00E33224  SUMA_$INIT

  - The identification byte set to 1 marks a sample as the bitpad's
    (tpad/tpad.ins.pas dev_id "1 bitpad"); SUMA_$RCV never writes it, so
    every sample keeps it.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure suma_$init;
begin
  suma_$tpad_buffer := addr(term_$tpad_buffer);
  suma_$rcv_state := 0;
  suma_$cur.id_flags := chr(1);
  suma_$threshold := suma_initial_threshold;
end;
