{ sio_$init_desc - fill in a line's SIO descriptor.

  Image addresses:
    sau2  0x00E32AB2  sio_$init_desc (module-local)
    sau3  0x00E3127C  sio_$init_desc (module-local)
    sau4  0x0F835C5E  sio_$init_desc (module-local)
    sau6  0x7803BF72  sio_$init_desc (module-local)
    sau7  0x3C43BFB6  sio_$init_desc (module-local)
    sau8  0x03C3647E  sio_$init_desc
    sau9  0x3C439486  sio_$init_desc (module-local)

  - The channel, the owner, the line's parameters, handlers and driver
    entries and the transmit buffer go in; the descriptor becomes the
    DTTE's tty_handler and SIO_$I_INIT resets its state.
  - A fragment of the OS_TERM_INIT module.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure sio_$init_desc(var desc: sio_$desc_t; in params: sio_$params_t;
                         var dtte: dtte_t; in owner: univ univ_ptr;
                         in txbuf: univ univ_ptr;
                         in handlers: univ sio_$handlers_t;
                         in context: univ univ_ptr;
                         in vtable: univ sio_$vtable_t);
  internal;
begin
  desc.context := context;
  desc.owner := owner;
  desc.params := params;
  desc.handlers := handlers;
  desc.driver := vtable.driver;
  desc.txbuf := txbuf;
  dtte.tty_handler := addr(desc);
  sio_$i_init(desc);
end;
