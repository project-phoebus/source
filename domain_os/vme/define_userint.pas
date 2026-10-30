{ VME_$DEFINE_USERINT - define the handler of a VME user interrupt.

  Image addresses:
    sau5  0x00E0ACB4  VME_$DEFINE_USERINT

  - With a handler, the handler and its argument go into the id's entry
    of VME_$USER_VEC; with nil the entry's handler becomes VME_$UNDEF_INT
    again.  The id is not checked.

  Status stored: none.
}

procedure vme_$define_userint(id: io_$int_id_t; handler: univ_ptr;
                              handler_arg: univ_ptr);
  options(val_param);
begin
  if handler <> nil then begin
    vme_$user_vec[id.vector].handler := handler;
    vme_$user_vec[id.vector].handler_arg := handler_arg;
  end
  else
    vme_$user_vec[id.vector].handler := addr(vme_$undef_int);
end;
