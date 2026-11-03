{ OS_$GET_EC - get the shutdown eventcount as an EC2 handle.

  Image addresses:
    sau2  0x00E6D6B8  OS_$GET_EC
    sau3  0x00E6DAC0  OS_$GET_EC

  - param_1 is not read.

  Status stored:
    status_$ok: the handle was returned
    ec2_$register_ec1's status, its fail bit set: the eventcount could
      not be registered
}

procedure os_$get_ec(in param_1: univ integer32; out ec_ret: univ_ptr;
                     out status: status_$t);
begin
  ec_ret := univ_ptr(ec2_$register_ec1(
              ec_$eventcount_ptr_t(addr(os_$shutdown_ec)), status));

  status.fail := status.all <> status_$ok;
end;
