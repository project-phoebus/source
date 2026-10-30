{ MT_$PRESENT - report whether the magnetic tape controller is present.

  Image addresses:
    sau5  0x00E7651A  MT_$PRESENT

  - True when the controller's PBU device is enabled; else the controller
    is probed with a byte written to its control register (TESTPAGE).

  Status stored: none.
}

function mt_$present;
var
  data: integer;
begin
  if mt_scb_enabled in mt_$scb.flags.bits then
    mt_$present := true
  else
    mt_$present := testpage(mt_probe_kind, addr(pbu_mt_page.control), data);
end;
