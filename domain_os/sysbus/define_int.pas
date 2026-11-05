{ SYSBUS_$DEFINE_INT - define a system bus interrupt's handler.

  Image addresses:
    sau2  0x00E0ABBC  SYSBUS_$DEFINE_INT
    sau3  0x00E0AC6A  SYSBUS_$DEFINE_INT
    sau4  0x0F80B348  SYSBUS_$DEFINE_INT
    sau6  0x7800B4D4  SYSBUS_$DEFINE_INT
    sau9  0x3C40C504  SYSBUS_$DEFINE_INT

  - With `sysbus_int_vec': the id's vector, 16#A0..16#AF, names the
    level (another vector crashes the system).
  - With `sysbus_vectors_90' or `sysbus_vectors_88' the vectors are
    SYSBUS_$INT's two ranges.  A handler is stored with its argument
    only while the level has SYSBUS_$UNDEF_INT; a level already defined
    is left as it is, without an error.  With `sysbus_vectors_88' a
    level already defined gets the handler as its second one, in the
    next entry of SYSBUS_$DUP_VEC (eight in all, not checked).  The
    image scales that index in 32 bits; dup_next is a word (its
    increment and reads are words), so the index is written as an
    integer32 transfer.  A nil handler
    puts SYSBUS_$UNDEF_INT back and leaves the argument.
  - Without it (the SAU2): the system crashes with
    status_$sysbus_unknown_interrupt_id, the parameters never read; the
    last routine of the module's segment.

  Status stored: none.
}

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
%if sysbus_vectors_90 or sysbus_vectors_88 %then
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
%if sysbus_vectors_88 %then
    end
    else begin
      sysbus_$int_vec[level].dup_slot := dup_next;
      sysbus_$dup_vec[integer32(dup_next)].handler := handler;
      sysbus_$dup_vec[integer32(dup_next)].handler_arg := handler_arg;
      dup_next := dup_next + 1;
%endif
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
