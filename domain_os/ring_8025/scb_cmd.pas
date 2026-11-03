{ ring_8025_scb_cmd - pass the controller a command with an address.

  Image addresses:
    sau8  0x03C8965E  ring_8025_scb_cmd
    sau9  0x3C485242  ring_8025_scb_cmd

  - The command and the physical address of buf go to the unit's
    system command block; the unit's command eventcount's next value is
    kept for ring_8025_wait_scb, and the controller is told to execute.
  - len, the length of the block at buf, is not used.

  Status stored: none.
}

procedure ring_8025_scb_cmd(u: ring_8025_$unit_ptr_t; cmd: integer;
                            buf: univ_ptr; len: integer); internal;
begin
  u^.scb^.parm := ring_8025_vtop(integer32(buf));
  u^.scb^.cmd := cmd;
  u^.flags := u^.flags + [r8025_unit_scb_busy];
  u^.scb_wait_val := ec_$read(u^.scb_ec) + 1;
  u^.regs^.sifcmd := r8025_sifcmd_execute;
end;
