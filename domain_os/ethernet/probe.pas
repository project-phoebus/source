{ ethernet_probe - check that an adapter answers at a register address.

  Image addresses:
    sau8  0x03C849C8  ethernet_probe
    sau9  0x3C4805C8  ethernet_probe

  - Ten times: the HCR's DIR bit is cleared and set, and the ASR's DIR
    must follow it each time.  The result is false at the first
    mismatch.
}

function ethernet_probe(var regs: ethernet_$regs_ptr_t): boolean; internal;
var
  i: integer;
begin
  for i := 1 to 10 do
    with regs^ do begin
      control := 0;
      if eth_asr_dir in status then begin
        ethernet_probe := false;
        return;
      end;
      control := eth_hcr_dir;
      if not (eth_asr_dir in status) then begin
        ethernet_probe := false;
        return;
      end;
    end;
  ethernet_probe := true;
end;
