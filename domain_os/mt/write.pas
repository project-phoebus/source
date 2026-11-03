{ MT_$WRITE - write a buffer to a magnetic tape unit.

  Image addresses:
    sau3  0x00E70FA0  MT_$WRITE
    sau5  0x00E76B10  MT_$WRITE

  - The unit is copied first: the request may change the copy (unit 4
    is taken as 1), not the caller's.

  Status stored:
    mt_$queue_request's status: the write was queued, or not
}

procedure mt_$write;
var
  u: integer;
begin
  u := unit;
  mt_$queue_request(u, mt_op_write, 0, buffer, length, status);
end;
