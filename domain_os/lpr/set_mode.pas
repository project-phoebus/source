{ lpr_set_mode - program the printer port for the current mode.

  Image addresses:
    sau3  0x00E6E724  lpr_set_mode (module-local; the map's
                      LPR_$PROC_START)

  - The mode table's values for lpr_state's mode (its low two bits)
    go into the port's registers, the control register written twice
    (after its low six bits are cleared), and the data mask into
    LPR_$DATA_MASK.
  - The map's LPR_$PROC_START, the mark of the driver's wired range, is
    at its first byte; the routine has no name of its own.

  Status stored: none.
}

procedure lpr_set_mode; internal;
begin
  with lpr_modes[lpr_state.mode & 3] do begin
    lpr.ctl := lpr.ctl & 16#C0;
    lpr.ctl := ctl_first;
    lpr.reg_04 := 16#FF;
    lpr.reg_06 := 0;
    lpr.reg_08 := reg_08;
    lpr.reg_02 := 8;
    lpr.reg_0c := 16#79;
    lpr.reg_0e := 0;
    lpr.reg_18 := reg_18;
    lpr.ctl := ctl_second;
    lpr_$data_mask := mask;
  end;
end;
