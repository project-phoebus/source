{ XPD_$GET_REGISTERS - read a stopped target's state.

  Image addresses:
    sau2  0x00E5C1A4  XPD_$GET_REGISTERS

  - The target (XPD_$FIND_INDEX, under the process-table lock) must
    have a published debug state.  By mode: 0 the register block; 1 the
    exception state; 2 the FP save area; 3 the debug state.

  Status stored:
    status_$ok: the state was read
    status_$xpd_state_unavailable_for_this_event: none published
    status_$xpd_invalid_option: another mode
    XPD_$FIND_INDEX's status: no such stopped target
}

{ TODO(pascal) the frames of the XPD_KER routines

  XPD_$GET_REGISTERS and XPD_$PUT_REGISTERS address only the UID's copy
  and st: 24 and 28 bytes above st and 36 and 28 below are unexplained.
  XPD_$FP_PUT_STATE and _$FP_GET_STATE have a 4-byte frame with no
  locals.  The stand-ins unused_20, unused_48, unused_24, unused_44 and
  unused_4 hold the places. }

procedure xpd_$get_registers(proc_uid: uid_$t; in mode: pinteger;
                             out regs: univ xpd_$reg_buf_t;
                             out status_ret: status_$t);
var
  index: integer;
  state: xpd_$debug_state_ptr_t;
  n: integer;
  i: integer;
  v: integer32;
  unused_20: array[1..2] of integer32;    { the TODO above }
  st: status_$t;
  unused_48: array[1..5] of integer32;    { the TODO above }
begin
  ml_$lock(ml_$proc2_lock);
  index := xpd_$find_index(proc_uid, st);
  ml_$unlock(ml_$proc2_lock);
  if st.all = status_$ok then
    with proc2_$info_table[index] do begin
      state := state_va;
      if state = nil then begin
        status_ret.all := status_$xpd_state_unavailable_for_this_event;
        return;
      end;

      case mode of
        xpd_$reg_mode_general:
          regs.regs := state^.regs^;
        xpd_$reg_mode_exception:
          with regs do begin
            exc_len := 12;
            exc_sr := state^.frame^.sr;
            exc_pc := state^.frame^.pc;
            if state^.aux^.len > 4 then begin
              exc_len := 12 + state^.aux^.len + 4;
              exc_sum := 0;
              exc_aux_len := state^.aux^.len;
              n := (state^.aux^.len - 4) div 4;
              for i := 1 to n do begin
                v := state^.aux^.data[i];
                exc_sum := exc_sum + v;
                exc_words[i] := v;
              end;
            end;
          end;
        xpd_$reg_mode_fp_state:
          with regs do begin
            fp_len := state^.fp_buf^.len;
            n := (state^.fp_buf^.len - 4) div 4;
            for i := 1 to n do
              fp_words[i] := state^.fp_buf^.data[i];
          end;
        xpd_$reg_mode_debug_state:
          with regs do begin
            dbg_signal := pad_94 & 16#FF;
            dbg_status := fault_param;
            dbg_status.signal_flag := false;
            dbg_pending := sig_mask_2;
            if fault_param.all = fault_$single_step then
              dbg_pc := last_pc
            else
              dbg_pc := 0;
          end;
        otherwise
          st.all := status_$xpd_invalid_option;
      end;
    end;

  status_ret := st;
end;
