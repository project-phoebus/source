{ VME_$DEFINE_INT - define the handler of a VME interrupt level.

  Image addresses:
    sau5  0x00E0AA94  VME_$DEFINE_INT

  - With a handler and an id below 8, the handler and its argument go
    into the id's entry of VME_$INT_VEC; otherwise the entry's handler
    becomes VME_$UNDEF_INT and the argument is left.
  - An id of 8 or more takes the `else' arm.

  Status stored: none.
}

{ TODO(merge) the id's word is compared unsigned

  The SAU5 image compares id.vector with 8 unsigned, straight from the
  parameter's slot: the form of a non-negative subrange in a word
  (pinteger) rather than of io_$int_id_t's `integer' vector
  (io/io.ins.pas).  MBUS_$DEFINE_INT's copy into a
  pinteger local is no help here (this routine has no frame for one).
  The field's type is to be settled at the merge; with `integer' dpc
  compares signed. }

procedure vme_$define_int(id: io_$int_id_t; handler: univ_ptr;
                          handler_arg: univ_ptr);
  options(val_param);
begin
  if (handler <> nil) and then (id.vector < vme_$n_levels) then begin
    vme_$int_vec[id.vector].handler := handler;
    vme_$int_vec[id.vector].handler_arg := handler_arg;
  end
  else
    vme_$int_vec[id.vector].handler := addr(vme_$undef_int);
end;
