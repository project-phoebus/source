{ PEB_$TEST_PARITY_ERR - report whether the board has a WCS parity error.

  Image addresses:
    sau2  0x00E11FF4  PEB_$TEST_PARITY_ERR

  Status stored:
    fault_$wcs_parity: the board is installed and its control word's
      parity bit is set
    fault_$eccu: otherwise ("uncorrectable memory error detected")
}

procedure peb_$test_parity_err(out status: status_$t);
begin
  if peb_$info.installed and then ((peb_ctl.ctl.all & 2) <> 0) then
    status.all := fault_$wcs_parity
  else
    status.all := fault_$eccu;
end;
