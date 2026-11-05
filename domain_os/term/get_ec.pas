{ TERM_$GET_EC - the EC2 handle of a terminal line's input or output
  eventcount.

  Image addresses:
    sau2  0x00E723C0  TERM_$GET_EC
    sau3  0x00E73AAC  TERM_$GET_EC
    sau4  0x0F87F99C  TERM_$GET_EC
    sau7  0x3C488A28  TERM_$GET_EC

  - The real line's DTTE input (0) or output (1) eventcount is
    registered (EC2_$REGISTER_EC1) and its handle handed back.

  Status stored:
    ec2_$register_ec1's status: the line was mapped
    term_$get_real_line's status: it was not
    status_$term_invalid_option: a number above 1
}

[section(procedure$, data$)]
procedure term_$get_ec(in ec_id: pinteger; in line: integer;
                       out ec_ret: univ_ptr; out status: status_$t);
var
  real_line: pinteger;
begin
  if ec_id > term_$ec_output then
    status.all := status_$term_invalid_option
  else begin
    real_line := term_$get_real_line(line, status);
    if status.all <> status_$ok then
      return;

    case ec_id of
      term_$ec_input:
        ec_ret := ec2_$register_ec1(addr(dtte[real_line].input_ec),
                                    status);
      term_$ec_output:
        ec_ret := ec2_$register_ec1(addr(dtte[real_line].output_ec),
                                    status);
    end;
  end;
end;
