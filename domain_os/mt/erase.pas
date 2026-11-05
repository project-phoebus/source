{ MT_$ERASE - erase tape on a magnetic tape unit.

  Image addresses:
    sau3  0x00E70940  MT_$ERASE
    sau4  0x0F87D6B8  MT_$ERASE
    sau5  0x00E764AA  MT_$ERASE
    sau6  0x7807D156  MT_$ERASE

  - option mt_erase_count takes a count above 0 (mt_op_erase),
    mt_erase_long a count of 0 (mt_op_erase_long).

  Status stored:
    mt_$queue_request's status: the erase was queued, or not
    status_$mt_invalid_count: count does not suit the option
    status_$mt_invalid_option: option is neither
}

procedure mt_$erase;
label
  9;
var
  op: integer;
  u: integer;
begin
  u := unit;
  case option of
    mt_erase_count: begin
      if count <= 0 then
        goto 9;
      op := mt_op_erase;
    end;
    mt_erase_long: begin
      if count <> 0 then
        goto 9;
      op := mt_op_erase_long;
    end;
    otherwise begin
      status.all := status_$mt_invalid_option;
      return;
    end;
  end;
  mt_$queue_request(u, op, 0, 0, count, status);
  return;
9:
  status.all := status_$mt_invalid_count;
end;
