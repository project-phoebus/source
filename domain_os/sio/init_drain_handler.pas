{ sio_$init_drain_handler - fill in the console's output drain record.

  Image addresses:
    sau2  0x00E32BB8  sio_$init_drain_handler (module-local)
    sau9  0x3C43958C  sio_$init_drain_handler (module-local)

  - The transmit buffer, TTY_$I_OUTPUT_BUFFER_DRAINED as the callback
    and the owner as its argument; the DTTE argument is not read.
  - A fragment of the OS_TERM_INIT module.
  - Compiled only with `display_driver' (base/config.ins.pas).

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure sio_$init_drain_handler(var drain: dtty_tstart_t; var dtte: dtte_t;
                                  in buffer: univ univ_ptr;
                                  in owner: univ univ_ptr);
  internal;
begin
  drain.buffer_info := buffer;
  drain.callback :=
    dtty_tstart_callback_t(addr(tty_$i_output_buffer_drained));
  drain.callback_arg := owner;
end;
