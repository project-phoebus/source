{ PEB_$UNLOAD_REGS - save the board's registers.

  Image addresses:
    sau2  0x00E5AEA6  PEB_$UNLOAD_REGS

  - Through the private register page, the board's output data
    registers, status, the register at 0x1DC and the control output
    register go into the state.

  Status stored: none.
}

procedure peb_$unload_regs(out state: peb_$fp_state_t);
var
  regs: peb_$regs_ptr_t;
begin
  regs := peb_$regs_ptr_t(16#7000);

  state.data1 := regs^.data_in;
  state.data2 := regs^.stat_in;
  state.status_reg := regs^.status;
  state.ctrl_reg := regs^.misc;
  state.instr_counter := regs^.ctrl_out;
end;
