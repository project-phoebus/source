{ MBUS_$DEFINE_INT - define the handler of a Multibus interrupt level.

  Image addresses:
    sau3  0x00E0AB38  MBUS_$DEFINE_INT
    sau4  0x0F80B21C  MBUS_$DEFINE_INT
    sau5  0x00E0AA24  MBUS_$DEFINE_INT
    sau6  0x7800B388  MBUS_$DEFINE_INT

  - A level above 15 crashes the system.
  - A nil handler puts MBUS_$UNDEF_INT back and leaves the argument.

  Status stored: none.
}

procedure mbus_$define_int(id: io_$int_id_t; handler: univ_ptr;
                           handler_arg: univ_ptr);
  options(val_param);
var
  level: pinteger;
begin
  level := id.vector;
  if level > mbus_$max_level then
    crash_system(status_$mbus_undefined_interrupt);
  if handler <> nil then begin
    mbus_$int_vec[level].handler := handler;
    mbus_$int_vec[level].handler_arg := handler_arg;
  end
  else
    mbus_$int_vec[level].handler := addr(mbus_$undef_int);
end;
