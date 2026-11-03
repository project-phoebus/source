{ ring_8025_scb_cmd_addr - pass the controller a command with a group or
  functional address.

  Image addresses:
    sau8  0x03C896AC  ring_8025_scb_cmd_addr
    sau9  0x3C485290  ring_8025_scb_cmd_addr

  - The command and the address's last four bytes go to the unit's
    system command block; then as ring_8025_scb_cmd.

  Status stored: none.
}

procedure ring_8025_scb_cmd_addr(u: ring_8025_$unit_ptr_t; cmd: integer;
                                 var a: ring_8025_$addr_t); internal;
var
  i: integer;
begin
  for i := 1 to 4 do
    u^.scb^.parm_bytes[i] := a.bytes[i + 2];
  u^.scb^.cmd := cmd;
  u^.flags := u^.flags + [r8025_unit_scb_busy];
  u^.scb_wait_val := ec_$read(u^.scb_ec) + 1;
  u^.regs^.sifcmd := r8025_sifcmd_execute;
end;
