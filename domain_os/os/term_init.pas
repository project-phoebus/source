{ os_term_init - set up a line's keyboard descriptor.

  Image addresses:
    sau2  0x00E32A60  os_term_init (module-local)
    sau4  0x0F835C0C  os_term_init (module-local)
    sau8  0x03C3642C  os_term_init
    sau9  0x3C439434  os_term_init (module-local)

  - A fragment of the OS_TERM_INIT module (term/os_term_init.pas, which
    includes it and holds its forward heading).
  - Compiled only with `display_driver' (base/config.ins.pas).
  - The descriptor and the line's DTTE are linked both ways before
    KBD_$INIT gets the descriptor.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure os_term_init(var kbd: kbd_$desc_t; var dtte: dtte_t;
                       in tty: univ univ_ptr; in rcv: univ univ_ptr;
                       in sio: univ univ_ptr;
                       in handlers: univ term_$kbd_handlers_view_t);
begin
  kbd.field_10 := sio;
  kbd.user_data := integer32(tty);
  kbd.key_ec := addr(dtte);
  kbd.handler := kbd_$handler_t(rcv);
  kbd.handlers := handlers.rest;
  dtte.alt_handler := addr(kbd);
  kbd_$init(kbd);
end;
