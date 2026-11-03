{ SMD_$GET_EC - export one of the display's eventcounts to user space.

  Image addresses:
    sau2  0x00E6FD90  SMD_$GET_EC
    sau4  0x0F87A692  SMD_$GET_EC
    sau5  0x00E722B6  SMD_$GET_EC
    sau9  0x3C4762B6  SMD_$GET_EC

  - key 0 is the input eventcount (DTTE line 0's first), 1 the display's
    scroll/BLT completion, 2 the SMD wired data's ec_2 (SMD_$SIGNAL's and
    the borrows'), 3 OS_$SHUTDOWN_EC.
  - The heading is Apollo's (smdu.ins.pas of SR10.2), but key is an
    integer: Apollo's smd_$ec_key_t has only the first two values.

  Status stored:
    ec2_$register_ec1's status: the handle was returned, or not
    smd_$illegal_caller: the process has no display unit
    smd_$invalid_key: key is not 0..3
}

{ TODO(pascal) 16 frame bytes of SMD_$GET_EC not accounted

  The frame has 0x10 bytes of locals, which nothing addresses (unit and
  hw are held in registers).  dpc's layout (`--dump-locals') gives the
  source above 8 bytes (unit and hw).  The other 8, and why the locals'
  slots are not used, are not known. }

procedure smd_$get_ec(in key: integer; out ecp: ec2_$ptr_t;
                      out status: status_$t);
var
  unit: integer;
  hw: smd_display_hw_ptr_t;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;

  status.all := status_$ok;
  hw := smd_$wired_data.unit[unit].hw;

  case key of
    smd_$input_ec:
      ecp := ec2_$register_ec1(addr(dtte[0].ec_00), status);
    smd_$scroll_blt_ec:
      ecp := ec2_$register_ec1(addr(hw^.op_ec), status);
    smd_$ec_key_smd_ec2:
      ecp := ec2_$register_ec1(addr(smd_$wired_data.ec_2), status);
    smd_$ec_key_shutdown:
      ecp := ec2_$register_ec1(addr(os_$shutdown_ec), status);
    otherwise
      status.all := smd_$invalid_key;
  end;
end;
