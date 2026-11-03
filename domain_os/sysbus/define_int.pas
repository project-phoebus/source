{ SYSBUS_$DEFINE_INT - define a system bus interrupt's handler.

  Image addresses:
    sau2  0x00E0ABBC  SYSBUS_$DEFINE_INT
    sau3  0x00E0AC6A  SYSBUS_$DEFINE_INT
    sau4  0x0F80B348  SYSBUS_$DEFINE_INT
    sau9  0x3C40C504  SYSBUS_$DEFINE_INT

  - With `sysbus_int_vec': the id's vector, 16#A0..16#AF, names the
    level (another vector crashes the system).
  - With `sysbus_vectors_90' the vectors are SYSBUS_$INT's two ranges.  A handler is stored with
    its argument only while the level has SYSBUS_$UNDEF_INT; a level
    already defined is left as it is, without an error.  A nil handler
    puts SYSBUS_$UNDEF_INT back and leaves the argument.
  - Without it (the SAU2): the system crashes with
    status_$sysbus_unknown_interrupt_id, the parameters never read; the
    last routine of the module's segment.

  Status stored: none.
}

{ TODO(sau) SYSBUS_$DEFINE_INT on the SAU6

  The SAU6's takes its SYSBUS_$INT's two ranges of vectors
  (sysbus/int.pas), with a duplicate vector it fills when the level is
  already defined.  To be written as a conditional arm when that SAU is
  translated. }

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
%if sysbus_vectors_90 %then
  else if (vector >= sysbus_$first_vector_2) and then
          (vector <= sysbus_$last_vector_2) then
    level := vector - (sysbus_$first_vector_2 - sysbus_$last_vector)
             - sysbus_$first_vector
%endif
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
