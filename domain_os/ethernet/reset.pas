{ ethernet_reset - reset an adapter and wait for it to come back.

  Image addresses:
    sau6  0x780869F8  ethernet_reset
    sau7  0x3C491200  ethernet_reset
    sau8  0x03C84A00  ethernet_reset
    sau9  0x3C480600  ethernet_reset

  - Attention and flush are pulsed in the HCR; the adapter shows both
    status flags while it resets and clears them when it is ready.  Each
    wait polls the ASR at most eth_reset_polls times.
  - With `ethernet_vme': the controller's reset register is written,
    and its status is polled for eth_vme_csr_ready, eth_reset_polls
    times at most.

  Status stored:
    status_$ok: the adapter came back
    status_$eth_adapter_hardware_error: either wait timed out
}

function ethernet_reset(var regs: ethernet_$regs_ptr_t;
                        out status: status_$t): boolean;
  internal;
var
  cnt: integer32;
  s: ethernet_$asr_t;
begin
%if ethernet_vme %then
  regs^.reset := 0;
  cnt := eth_reset_polls;
  repeat
    if cnt = 0 then begin
      status.all := status_$eth_adapter_hardware_error;
      ethernet_reset := false;
      return;
    end;
    cnt := cnt - 1;
    s := regs^.csr_bits;
  until eth_vme_csr_ready in s;
  status.all := status_$ok;
  ethernet_reset := true;
%else
  with regs^ do begin
    control := eth_hcr_attn ! eth_hcr_flsh;
    control := 0;
  end;
  cnt := eth_reset_polls;
  repeat
    if cnt = 0 then begin
      status.all := status_$eth_adapter_hardware_error;
      ethernet_reset := false;
      return;
    end;
    cnt := cnt - 1;
    s := regs^.status;
  until (eth_asr_asf1 in s) and then (eth_asr_asf2 in s);
  cnt := eth_reset_polls;
  repeat
    if cnt = 0 then begin
      status.all := status_$eth_adapter_hardware_error;
      ethernet_reset := false;
      return;
    end;
    cnt := cnt - 1;
    s := regs^.status;
  until not (eth_asr_asf1 in s) and then not (eth_asr_asf2 in s);
  status.all := status_$ok;
  ethernet_reset := true;
%endif
end;
