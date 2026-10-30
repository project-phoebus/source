{ KBD_$OUTPUT_BUFFER_DRAINED - the console's transmit buffer has drained.

  Image addresses:
    sau2  0x00E1CE96  KBD_$OUTPUT_BUFFER_DRAINED

  - The descriptor's eventcount is advanced without dispatching.

  Status stored: none.
}

procedure kbd_$output_buffer_drained(var kbd: kbd_$desc_t);
begin
  ec_$advance_without_dispatch(kbd.ec);
end;
