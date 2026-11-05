{ ethernet_probe - check that an adapter answers at a register address.

  Image addresses:
    sau6  0x780869C8  ethernet_probe
    sau7  0x3C4911C8  ethernet_probe
    sau8  0x03C849C8  ethernet_probe
    sau9  0x3C4805C8  ethernet_probe

  - Ten times: the HCR's DIR bit is cleared and set, and the ASR's DIR
    must follow it each time.  The result is false at the first
    mismatch.
  - With `ethernet_vme': the controller's reset register is written and
    its status must be one of the values a present controller shows.
}

function ethernet_probe(var regs: ethernet_$regs_ptr_t): boolean; internal;
%if ethernet_vme %then
var
  s: integer;
begin
  regs^.reset := 0;
  s := regs^.csr;
  if (s = 1) or else (s = 0) or else (s = 16#41) then
    ethernet_probe := true
  else
    ethernet_probe := false;
end;
%else
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
%endif
