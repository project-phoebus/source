{ ethernet_kick - write a byte to the VME controller's command register.

  Image addresses:
    sau6  0x78086A3E  ethernet_kick

  - With `ethernet_vme' only.  The status register is polled until its
    eth_vme_csr_busy bit is clear, eth_cmd_byte_polls times at most,
    and the byte is then written to the command register.

  Status stored:
    status_$ok: the byte was written
    status_$eth_adapter_hardware_error: the register stayed busy
}

function ethernet_kick(var regs: ethernet_$regs_ptr_t; cmd: ethernet_$byte_t;
                       out status: status_$t): boolean;
  internal;
var
  cnt: integer32;
  s: ethernet_$asr_t;
begin
  cnt := eth_cmd_byte_polls;
  repeat
    if cnt = 0 then begin
      status.all := status_$eth_adapter_hardware_error;
      ethernet_kick := false;
      return;
    end;
    cnt := cnt - 1;
    s := regs^.csr_bits;
  until not (eth_vme_csr_busy in s);
  regs^.csr := cmd;
  status.all := status_$ok;
  ethernet_kick := true;
end;
