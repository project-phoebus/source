{ MT_$SPACE - space the tape on a magnetic tape unit.

  Image addresses:
    sau3  0x00E70CF0  MT_$SPACE
    sau4  0x0F87DA68  MT_$SPACE
    sau5  0x00E7685A  MT_$SPACE

  - mode selects the operation (mt/mt.ins.pas); mode 2 has its own for
    a count of 1.

  Status stored:
    mt_$queue_request's status: the operation was queued, or not
    status_$mt_invalid_count: count is 0 or less
    status_$mt_invalid_option: mode is not 0..2
}

procedure mt_$space;
var
  u: integer;
  op: integer;
begin
  u := unit;
  if count <= 0 then begin
    status.all := status_$mt_invalid_count;
    return;
  end;
  case mode of
    mt_space_mode_0: begin
      op := mt_op_space_mode_0;
    end;
    mt_space_mode_1: begin
      op := mt_op_space_mode_1;
    end;
    mt_space_mode_2: begin
      if count = 1 then
        op := mt_op_space_mode_2_one
      else
        op := mt_op_space_mode_2;
    end;
    otherwise begin
      status.all := status_$mt_invalid_option;
      return;
    end;
  end;
  mt_$queue_request(u, op, 0, 0, count, status);
end;
