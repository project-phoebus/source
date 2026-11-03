{ PBU_$GET_EC - the EC2 handle of a PBU unit's eventcount.

  Image addresses:
    sau3  0x00E590A2  PBU_$GET_EC
    sau5  0x00E59272  PBU_$GET_EC

  - which 0 is the unit's eventcount (the one its interrupts advance),
    registered as a level-2 eventcount.

  Status stored:
    ec2_$register_ec1's status, its fail bit set when not ok: the
      handle was returned, or not
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_bad_parameter: which is not 0
}

procedure pbu_$get_ec(in unit: integer; in which: integer;
                      out ec: ec2_$ptr_t; out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if which <> 0 then begin
    status.all := status_$pbu_bad_parameter;
    return;
  end;
  ec := ec2_$register_ec1(dcte^.ec_ptr, status);
  status.fail := status.all <> status_$ok;
end;
