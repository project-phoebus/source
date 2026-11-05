{ SMD_$BLT_U - check a user's BLT request and start it.

  Image addresses:
    sau2  0x00E6FAE2  SMD_$BLT_U
    sau4  0x0F87A3A2  SMD_$BLT_U
    sau5  0x00E71F98  SMD_$BLT_U
    sau6  0x780792AC  SMD_$BLT_U

  - Valid coordinates: the ends at most 1023, the starts' sign bits
    clear.
  - The heading is Apollo's (smdu.ins.pas).

  Status stored:
    status_$ok: the request passed the checks and went to SMD_$BLT
    smd_$invalid_blt_mode: the mode asks for a transfer to or from main
      memory
    smd_$invalid_blt_ctl: a control longword is not one of the four
    smd_$invalid_blt_coord: a coordinate is out of range
    smd_$blt's status: the BLT was refused or failed
}

procedure smd_$blt_u(in blt_regs: smd_$blt_regs_t; out status: status_$t);
var
  mode: smd_$display_modereg_t;
  valid: boolean;
begin
  status.all := status_$ok;
  mode := smd_$display_modereg_t(blt_regs.mode);
  if mode.to_mm or else mode.from_mm then
    status.all := smd_$invalid_blt_mode;
  if status.all = status_$ok then begin
    valid := smd_$is_valid_blt_ctl(blt_regs.cs)
             and smd_$is_valid_blt_ctl(blt_regs.cd);
    if not valid then
      status.all := smd_$invalid_blt_ctl
    else if (blt_regs.edy > 1023)
            or else (integer(blt_regs.sdy) < 0)
            or else (blt_regs.esy > 1023)
            or else (integer(blt_regs.ssy) < 0)
            or else (blt_regs.edx > 1023)
            or else (integer(blt_regs.sdx) < 0)
            or else (integer(blt_regs.ssx) < 0)
            or else (blt_regs.esx > 1023) then
      status.all := smd_$invalid_blt_coord;
    if status.all = status_$ok then
      smd_$blt(blt_regs, 0, 0, status);
  end;
end;
