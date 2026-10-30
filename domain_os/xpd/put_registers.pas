{ XPD_$PUT_REGISTERS - change a stopped target's state.

  Image addresses:
    sau2  0x00E5C33C  XPD_$PUT_REGISTERS
    sau9  0x3C463418  XPD_$PUT_REGISTERS

  - As XPD_$GET_REGISTERS the other way: mode 0 the register block; 1
    the SR, PC and auxiliary area (checksummed, at most 212 longwords);
    2 the FP save area (at most 108 longwords).
  - The mode switch runs whatever the lookup's status; the limits count
    longwords.

  Status stored:
    status_$ok: the state was changed
    status_$xpd_invalid_state_argument: a bad checksum or count
    status_$xpd_invalid_option: another mode
    XPD_$FIND_INDEX's status: no such stopped target
}

procedure xpd_$put_registers(proc_uid: uid_$t; in mode: pinteger;
                             in regs: univ xpd_$reg_buf_t;
                             out status_ret: status_$t);
var
  index: integer;
  state: xpd_$debug_state_ptr_t;
  n: integer;
  sum: integer32;
  i: integer;
  unused_24: array[1..5] of integer;      { xpd/get_registers.pas's
                                            TODO }
  st: status_$t;
  unused_44: array[1..5] of integer32;    { xpd/get_registers.pas's
                                            TODO }
begin
  ml_$lock(ml_$proc2_lock);
  index := xpd_$find_index(proc_uid, st);
  ml_$unlock(ml_$proc2_lock);

  if st.all = status_$ok then
    state := proc2_$info_table[index].state_va;

  case mode of
    xpd_$reg_mode_general:
      state^.regs^ := regs.regs;
    xpd_$reg_mode_exception:
      with regs do begin
        if put_len <= 12 then begin
          state^.aux^.len := 0;
          state^.fp_modified := true;
        end
        else begin
          n := (put_aux_len - 4) div 4;
          sum := 0;
          for i := 1 to n do
            sum := sum + put_words[i];
          if (sum <> put_sum) or else (n > 212) then begin
            status_ret.all := status_$xpd_invalid_state_argument;
            return;
          end;
          for i := 1 to n do
            state^.aux^.data[i] := put_words[i];
          state^.aux^.len := put_aux_len;
          state^.fp_modified := true;
        end;
        state^.frame^ := put_sr_pc;
      end;
    xpd_$reg_mode_fp_state:
      with regs do begin
        state^.fp_buf^.len := fp_len;
        n := (fp_len - 4) div 4;
        if n > 108 then begin
          status_ret.all := status_$xpd_invalid_state_argument;
          return;
        end;
        for i := 1 to n do
          state^.fp_buf^.data[i] := fp_words[i];
        state^.fp_modified := true;
      end;
    otherwise
      st.all := status_$xpd_invalid_option;
  end;

  status_ret := st;
end;
