{ ATBUS_$INT - dispatch an AT bus interrupt to its handler.

  Image addresses:
    sau8  0x03C0B7B0  ATBUS_$INT

  - The interrupt's controller input is masked and the controller told
    the end of the interrupt (the slave and then the master for 8..15);
    the input is unmasked again only when the handler returns true.
  - The vector is not checked: ATBUS_$INIT traps only 16#A0..16#AF.

  Status stored: none.
}

procedure atbus_$int(vector: integer);
  options(val_param);
var
  irq: pinteger;
  bit: integer;
  handler: atbus_$handler_t;
  handler_arg: univ_ptr;
begin
  irq := vector - atbus_$first_vector;
  if irq <= 7 then
    pic1.m_imr_bits := pic1.m_imr_bits + [irq]
  else begin
    bit := irq & 7;
    pic1.s_imr_bits := pic1.s_imr_bits + [bit];
    pic1.s_cmd := atbus_$eoi;
  end;
  pic1.m_cmd := atbus_$eoi;

  handler := atbus_$int_vec[irq].handler;
  handler_arg := atbus_$int_vec[irq].handler_arg;
  if handler^(handler_arg) then
    if irq <= 7 then
      pic1.m_imr_bits := pic1.m_imr_bits - [irq]
    else
      pic1.s_imr_bits := pic1.s_imr_bits - [bit];
end;
