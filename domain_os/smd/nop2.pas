{ SMD_$NOP2 - the default for a device routine that takes only a status.

  Image addresses:
    sau7  0x3C421A00  SMD_$NOP2
    sau9  0x3C420118  SMD_$NOP2

  - The default of the vector's install_disp, dissoc and busy_wait
    routines: it succeeds.

  Status stored:
    status_$ok: always
}

[section(wired_proc, wired_data)]
procedure smd_$nop2(dcte: univ_ptr; out status: status_$t);
  options(val_param);
begin
  status.all := status_$ok;
end;
