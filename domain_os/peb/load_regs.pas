{ PEB_$LOAD_REGS - load the board's registers from a saved state.

  Image addresses:
    sau2  0x00E5AE60  PEB_$LOAD_REGS

  - Through the private register page at 16#7000, the state's two data
    registers, status, control and instruction counter go into the
    board's input registers.

  Status stored: none.
}

procedure peb_$load_regs(in state: peb_$fp_state_t);
var
  regs: peb_$regs_ptr_t;
begin
  regs := peb_$regs_ptr_t(16#7000);

  regs^.data_out := state.data1;
  regs^.stat_out := state.data2;
  regs^.status := state.status_reg;
  regs^.ctrl_in := state.ctrl_reg;
  regs^.ctrl_out := state.instr_counter;
end;
