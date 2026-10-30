{ SMD_$NOP_TOUCH - the default for a device's touch of its memory.

  Image addresses:
    sau9  0x3C42014A  SMD_$NOP_TOUCH

  - Refuses the address and returns 0.

  Status stored:
    status_$reference_to_illegal_address: always
}

[section(wired_proc, wired_data)]
function smd_$nop_touch(dcte: univ_ptr; var arg_1: integer32;
                        out status: status_$t): integer32;
  options(val_param);
begin
  status.all := status_$reference_to_illegal_address;
  smd_$nop_touch := 0;
end;
