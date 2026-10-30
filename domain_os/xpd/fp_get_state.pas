{ XPD_$FP_GET_STATE - save a target's FP state into its save areas.

  Image addresses:
    sau2  0x00E5C50E  XPD_$FP_GET_STATE
    sau9  0x3C4635BE  XPD_$FP_GET_STATE

  - The auxiliary area is emptied first; with a 68881,
    FIM_$FP_GET_STATE fills both; else with a PEB, PEB_$UNLOAD_REGS
    fills the PEB part and the lengths are set to 32 and 4.
  - Without `peb_board' always FIM_$FP_GET_STATE.

  Status stored: none.
}

procedure xpd_$fp_get_state(out fp_buf: xpd_$fp_buf_t; out aux: xpd_$aux_buf_t);
%if peb_board %then
var
  unused_4: integer32;                    { xpd/get_registers.pas's
                                            TODO }
%endif
begin
  aux.len := 0;
%if peb_board %then
  if peb_$info.m68881_save_flag then
    fim_$fp_get_state(fp_buf, aux)
  else if peb_$info.installed then begin
    peb_$unload_regs(fp_buf.peb_state);
    fp_buf.len := 32;
    aux.len := 4;
  end;
%else
  fim_$fp_get_state(fp_buf, aux);
%endif
end;
