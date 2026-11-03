{ MBUS_$DEFINE_INT - define the handler of a Multibus interrupt level.

  Image addresses:
    sau3  0x00E0AB38  MBUS_$DEFINE_INT
    sau5  0x00E0AA24  MBUS_$DEFINE_INT

  - A level above 15 crashes the system.
  - A nil handler puts MBUS_$UNDEF_INT back and leaves the argument.

  Status stored: none.
}

{ TODO(sau) MBUS_$DEFINE_INT on the SAU6

  The SAU6's MBUS_$DEFINE_INT is other code; the SAU3's and SAU4's are
  the same as this one.  To be written as a conditional arm when the
  SAU6 is translated. }

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
