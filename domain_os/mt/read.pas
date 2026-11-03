{ MT_$READ - read a block from a magnetic tape unit into a buffer.

  Image addresses:
    sau3  0x00E70AB8  MT_$READ
    sau5  0x00E76622  MT_$READ

  - A negative unit is a dump: length + 1 words of the MT page
    (MT_$SCB among them) are copied into the buffer.
  - The dump returns MT_$SCB's address as the status.

  Status stored:
    mt_$queue_request's status: the read was queued, or not
    status_$mt_invalid_buffer_address: the buffer is below AS_$PRIVATE
      (a signed compare)
    MT_$SCB's address: a dump
}

procedure mt_$read;
var
  u: integer;
  i: integer;
begin
  if unit < 0 then begin
    for i := 0 to length do
      buffer[i] := mt_$page_start[i];
    status.all := integer32(addr(mt_$scb));
  end
  else if integer32(addr(buffer)) < as_$private then
    status.all := status_$mt_invalid_buffer_address
  else begin
    u := unit;
    mt_$queue_request(u, mt_op_read, 0, buffer, length, status);
  end;
end;
