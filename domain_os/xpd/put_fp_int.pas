{ XPD_$PUT_FP_INT - restore an address space's FP state.

  Image addresses:
    sau2  0x00E5C58E  XPD_$PUT_FP_INT
    sau9  0x3C4635FA  XPD_$PUT_FP_INT

  - With a 68881, FP_$PUT_FP (the address space by value); else
    PEB_$PUT_FP (by address).  Without `peb_board' always FP_$PUT_FP.

  Status stored:
    status_$ok: always
}

procedure xpd_$put_fp_int(in asid: integer; out status_ret: status_$t);
begin
  status_ret.all := status_$ok;
%if peb_board %then
  if peb_$info.m68881_save_flag then
    fp_$put_fp(asid)
  else
    peb_$put_fp(asid);
%else
  fp_$put_fp(asid);
%endif
end;
