{ SIO_$INIT - set up one serial port's terminal line.

  Image addresses:
    sau2  0x00E32BE0  SIO_$INIT
    sau3  0x00E31380  SIO_$INIT
    sau8  0x03C365AC  SIO_$INIT
    sau9  0x3C4395B4  SIO_$INIT

  - Port 1, the console, gets its keyboard, TTY and SIO descriptors with
    the console's handlers, its drain record and a DTTE of discipline 2
    (with `sio16550_lines' its channel is recorded for KBD_$RESET);
    another port the serial handlers and a DTTE of discipline 0.
  - Without `display_driver' port 1 is set up as a serial line, with
    the serial handlers and a DTTE of discipline 2.
  - Then the ESC crash character (crash), or the driver's set_params
    with every selector; the SIO descriptor is handed back.
  - A fragment of the OS_TERM_INIT module.  With `sio16550_lines' the
    serial driver's initialization calls it for each of its ports;
    nothing in the SAU2 image calls it.

  Status stored:
    status_$ok: the console, or the crash character
    the driver's set_params status: another port without crash
}

[section(os_init_proc, os_init_data)]
procedure sio_$init(port: integer; in context: univ univ_ptr;
                    in vtable: univ sio_$vtable_t;
                    out desc_ret: sio_$desc_ptr_t; crash: boolean;
                    out status: status_$t);
  options(val_param);
begin
  status.all := status_$ok;

  if port = 1 then begin
%if display_driver %then
    { ---- the console ---- }
    { its keyboard descriptor }
    os_term_init(kbd_descs[port], dtte[term_$max_dtte],
                 addr(tty_descs[port]), term_$kbd_rcv,
                 addr(sio_descs[port]), term_$kbd_handlers);

    { its TTY descriptor }
    sio_$init_line(tty_descs[port], dtte[term_$max_dtte],
                   addr(term_$console_drain[port]),
                   term_$console_line_handlers);

    { its output drain record }
    sio_$init_drain_handler(term_$console_drain[port],
                            dtte[term_$max_dtte],
                            addr(tty_descs[port].output),
                            addr(tty_descs[port]));

    { its SIO descriptor }
    sio_$init_desc(sio_descs[port], term_$console_params,
                   dtte[term_$max_dtte], addr(kbd_descs[port]),
                   addr(kbd_descs[port].txbuf), term_$console_handlers,
                   context, vtable);
%if sio16550_lines %then

    { the channel KBD_$RESET writes to }
    term_$console_chan_ptr := sio_descs[port].context;
%endif

    sio_$init_dtte(dtte[term_$max_dtte], 2);
%else
    { ---- the console, a serial line ---- }
    { its TTY descriptor }
    sio_$init_line(tty_descs[port], dtte[term_$max_dtte],
                   addr(sio_descs[port]), term_$serial_line_handlers);

    { its SIO descriptor }
    sio_$init_desc(sio_descs[port], term_$serial_params,
                   dtte[term_$max_dtte], addr(tty_descs[port]),
                   addr(tty_descs[port].output), term_$tty_handlers,
                   context, vtable);

    sio_$init_dtte(dtte[term_$max_dtte], 2);
%endif
  end
  else begin
    { ---- a serial line ---- }
    { its TTY descriptor }
    sio_$init_line(tty_descs[port], dtte[term_$max_dtte],
                   addr(sio_descs[port]), term_$serial_line_handlers);

    { its SIO descriptor }
    sio_$init_desc(sio_descs[port], term_$serial_params,
                   dtte[term_$max_dtte], addr(tty_descs[port]),
                   addr(tty_descs[port].output), term_$tty_handlers,
                   context, vtable);

    sio_$init_dtte(dtte[term_$max_dtte], 0);

    { the crash character, or the line set up }
    if crash then begin
      tty_$i_enable_crash_func(tty_descs[port], chr(16#1B), true);
      status.all := status_$ok;
    end
    else
      with sio_descs[port] do
        sio_$set_params_t(driver.set_params)^(context, params, [0..13],
                                              status);
  end;

  desc_ret := addr(sio_descs[port]);
  term_$max_dtte := term_$max_dtte + 1;
end;
