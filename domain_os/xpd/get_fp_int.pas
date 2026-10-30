{ XPD_$GET_FP_INT - save an address space's FP state.

  Image addresses:
    sau2  0x00E5C55A  XPD_$GET_FP_INT
    sau9  0x3C4635DE  XPD_$GET_FP_INT

  - With a 68881, FP_$GET_FP (the address space by value); else
    PEB_$GET_FP (by address).  Without `peb_board' always FP_$GET_FP.

  Status stored:
    status_$ok: always
}

procedure xpd_$get_fp_int(in asid: integer; out status_ret: status_$t);
begin
  status_ret.all := status_$ok;
%if peb_board %then
  if peb_$info.m68881_save_flag then
    fp_$get_fp(asid)
  else
    peb_$get_fp(asid);
%else
  fp_$get_fp(asid);
%endif
end;
