{ SIO_$I_RCV - a character received on a serial line.

  Image addresses:
    sau2  0x00E1C620  SIO_$I_RCV
    sau4  0x0F81D834  SIO_$I_RCV

  - Enabled error bits (params.break_mask) become pending conditions;
    condition 5 calls the special-receive handler when the line asks for
    receive-error notification.
  - The character goes to the data_rcv handler when a condition is
    pending and it exists, else to the receive handler.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure sio_$i_rcv(desc: sio_$desc_ptr_t; char_data: char;
                     error_flags: integer32);
  options(val_param);
begin
  if error_flags <> 0 then begin
    desc^.pending_int := desc^.pending_int
                         + (sio_$flags_t(error_flags)
                            * desc^.params.break_mask);
    if (5 in desc^.pending_int)
       and then (3 in desc^.params.flags2)
       and then (desc^.handlers.special_rcv <> nil) then
      sio_$owner_proc_t(desc^.handlers.special_rcv)^(desc^.owner);
    if (desc^.pending_int <> [])
       and then (desc^.data_rcv <> nil) then
      sio_$rcv_proc_t(desc^.data_rcv)^(desc^.owner, char_data)
    else
      sio_$rcv_proc_t(desc^.handlers.rcv_handler)^(desc^.owner,
                                                    char_data);
  end
  else
    sio_$rcv_proc_t(desc^.handlers.rcv_handler)^(desc^.owner, char_data);
end;
