{ SYSBUS_$DEFINE_INT - define a system bus interrupt's handler.

  Image addresses:
    sau2  0x00E0ABBC  SYSBUS_$DEFINE_INT
    sau9  0x3C40C504  SYSBUS_$DEFINE_INT

  - With `sysbus_int_vec': the id's vector, 16#A0..16#AF, names the
    level (another vector crashes the system).  A handler is stored with
    its argument only while the level has SYSBUS_$UNDEF_INT; a level
    already defined is left as it is, without an error.  A nil handler
    puts SYSBUS_$UNDEF_INT back and leaves the argument.
  - Without it (the SAU2): the system crashes with
    status_$sysbus_unknown_interrupt_id, the parameters never read; the
    last routine of the module's segment.

  Status stored: none.
}

{ TODO(sau) SYSBUS_$DEFINE_INT on the SAU3, SAU4 and SAU6

  The SAU3's is the SAU2's.  The SAU4's and SAU6's take their
  SYSBUS_$INT's two ranges of vectors (sysbus/int.pas), the SAU6's
  with a duplicate vector it fills when the level is already defined.
  The `sysbus_int_vec' arm below is the SAU9's.  To be written as
  conditional arms when those SAUs are translated. }

%if sysbus_int_vec %then
[section(wired_proc, wired_data)]
procedure sysbus_$define_int(id: io_$int_id_t; handler: univ_ptr;
                             handler_arg: univ_ptr);
  options(val_param);
var
  vector: integer;
  level: sysbus_$level_t;
begin
  vector := id.vector;
  if (vector >= sysbus_$first_vector) and then
     (vector <= sysbus_$last_vector) then
    level := vector - sysbus_$first_vector
  else
    crash_system(status_$sysbus_unknown_interrupt_id);
  if handler <> nil then begin
    if sysbus_$int_vec[level].handler = addr(sysbus_$undef_int) then begin
      sysbus_$int_vec[level].handler := handler;
      sysbus_$int_vec[level].handler_arg := handler_arg;
    end;
  end
  else
    sysbus_$int_vec[level].handler := addr(sysbus_$undef_int);
end;
%else
[section(wired_proc, wired_data)]
procedure sysbus_$define_int(id: io_$int_id_t; handler: univ_ptr;
                             handler_arg: univ_ptr);
  options(val_param);
begin
  crash_system(status_$sysbus_unknown_interrupt_id);
end;
%endif
