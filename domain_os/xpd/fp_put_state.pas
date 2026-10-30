{ XPD_$FP_PUT_STATE - restore a target's FP state from its save areas.

  Image addresses:
    sau2  0x00E5C4D0  XPD_$FP_PUT_STATE
    sau9  0x3C4635A8  XPD_$FP_PUT_STATE

  - With a 68881, through FIM_$FP_PUT_STATE; else with a PEB,
    PEB_$LOAD_REGS from the save area's PEB part; else nothing.
  - Without `peb_board' always through FIM_$FP_PUT_STATE.

  Status stored: none.
}

procedure xpd_$fp_put_state(in fp_buf: xpd_$fp_buf_t; in aux: xpd_$aux_buf_t);
%if peb_board %then
var
  unused_4: integer32;                    { xpd/get_registers.pas's
                                            TODO }
%endif
begin
%if peb_board %then
  if peb_$info.m68881_save_flag then
    fim_$fp_put_state(fp_buf, aux)
  else if peb_$info.installed then
    peb_$load_regs(fp_buf.peb_state);
%else
  fim_$fp_put_state(fp_buf, aux);
%endif
end;
