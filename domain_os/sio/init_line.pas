{ sio_$init_line - fill in a line's TTY descriptor.

  Image addresses:
    sau2  0x00E32B26  sio_$init_line (module-local)
    sau3  0x00E312EE  sio_$init_line (module-local)
    sau4  0x0F835CD2  sio_$init_line (module-local)
    sau6  0x7803BFE6  sio_$init_line (module-local)
    sau7  0x3C43C02A  sio_$init_line (module-local)
    sau8  0x03C364F2  sio_$init_line
    sau9  0x3C4394FA  sio_$init_line (module-local)

  - The line id (the SIO descriptor's or the console drain record's
    address), the four TTY handlers and the DTTE's two eventcounts go
    in; TTY_$I_INIT initializes it and it becomes the DTTE's handler.
  - A fragment of the OS_TERM_INIT module.

  Status stored: none.
}

{ TODO(pascal) The TTY descriptor's four handlers copied as one record

  The image copies 16 bytes from the line handler block's +8 into the
  TTY descriptor's +0x2B4 through two address registers: a record
  assignment, not four field stores, which would carry the displacements
  0x2B4..0x2C0.  So the original's TTY descriptor held xmit_callback,
  xon_xoff_handler, flow_ctrl_handler and status_handler as one record;
  tty/tty.ins.pas tty_$desc_t has them as four fields, which the TTY
  fragments name (tty/i_put_chars.pas, i_rcv.pas, i_flush.pas,
  i_err.pas, k_get.pas, k_put.pas).  Here the copy goes through the
  address of the first field converted to a pointer to the group's
  record (sio/sio.ins.pas sio_$tty_handlers_ptr_t), which gives the same
  instructions.  Grouping the four fields in tty_$desc_t (and the TTY
  fragments' references with them) is the reading of the image; that
  change is TTY's to make. }

[section(os_init_proc, os_init_data)]
procedure sio_$init_line(var tty: tty_$desc_t; var dtte: dtte_t;
                         in context: univ univ_ptr;
                         in handlers: univ sio_$line_handlers_t);
  internal;
begin
  tty.line_id := integer32(context);
  sio_$tty_handlers_ptr_t(addr(tty.xmit_callback))^ := handlers.tty;
  tty.input_ec := addr(dtte.input_ec);
  tty.output_ec := addr(dtte.output_ec);
  tty_$i_init(tty);
  dtte.handler_ptr := addr(tty);
end;
