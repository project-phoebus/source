{ MT_$CONTROL - queue a control operation on a magnetic tape unit.

  Image addresses:
    sau5  0x00E76402  MT_$CONTROL

  - func (0..8) selects the operation (mt/mt.ins.pas); function 8
    starts a batch (mt_op_go).

  Status stored:
    mt_$queue_request's status: the operation was queued, or not
    status_$mt_will_not_fit_thru_hatch: func is 7 ("unit will not fit
      thru 25" hatch", Apollo's joke status)
    status_$mt_invalid_option: func is not 0..8
}

procedure mt_$control;
var
  op: integer;
  u: integer;
begin
  u := unit;
  case func of
    mt_control_0: begin
      op := mt_op_control_0;
    end;
    mt_control_1: begin
      op := mt_op_control_1;
    end;
    mt_control_2: begin
      op := mt_op_control_2;
    end;
    mt_control_3: begin
      op := mt_op_control_3;
    end;
    mt_control_4: begin
      op := mt_op_control_4;
    end;
    mt_control_5: begin
      op := mt_op_control_5;
    end;
    mt_control_6: begin
      op := mt_op_control_6;
    end;
    mt_control_8: begin
      op := mt_op_go;
    end;
    mt_control_7: begin
      status.all := status_$mt_will_not_fit_thru_hatch;
      return;
    end;
    otherwise begin
      status.all := status_$mt_invalid_option;
      return;
    end;
  end;
  mt_$queue_request(u, op, 0, 0, 0, status);
end;
