{ KBD_$INIT - initialize a keyboard descriptor.

  Image addresses:
    sau2  0x00E33364  KBD_$INIT
    sau9  0x3C4399A0  KBD_$INIT

  - TERM_$TPAD_BUFFER is emptied and becomes the descriptor's; the
    keyboard type is "2", the key ring and transmit buffer empty (64
    bytes each, the ring 512 with `kbd_key_ring_512').
  - With `kbd_commands' the descriptor is recorded for KBD_$CRASH_INIT.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure kbd_$init(var kbd: kbd_$desc_t);
begin
  { the touchpad buffer is empty }
  term_$tpad_buffer.head := 0;
  term_$tpad_buffer.tail := 0;

  kbd.state := 0;
%if kbd_commands %then
  kbd.kbd_type_idx := 0;
  kbd.sub_state := 0;
%else
  kbd.sub_state := 0;
  kbd.kbd_type_idx := 0;
%endif
  kbd.pending_mode := 0;
  kbd.flags := [];

  kbd_$set_type(kbd, '2', 1);
%if kbd_commands %then
  kbd_$console_desc := addr(kbd);
%endif
  kbd.tpad_buffer := addr(term_$tpad_buffer);
  ec_$init(kbd.ec);

  { the key ring and the transmit buffer }
  kbd.ring.head := 1;
  kbd.ring.tail := 1;
  kbd.ring.size := kbd_$key_ring_size;
  kbd.txbuf.head := 1;
  kbd.txbuf.tail := 1;
  kbd.txbuf.size := kbd_$ring_size;
end;
