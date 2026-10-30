{ ring_$clear_dma_channel - stop one of the ring's DMA channels.

  Image addresses:
    sau2  0x00E757E0  ring_$clear_dma_channel (module-local)

  - A channel still active, or a receive channel whose unit's receive
    status has bit 0, is aborted; else a channel error crashes the
    system.  The channel's status is then cleared.
  - Not compiled for a controller that moves its packets itself
    (`ring_controller_dma'), which has no DMA channels.

  Status stored: none.
}

%if not ring_controller_dma %then
procedure ring_$clear_dma_channel(channel: integer; unit: integer);
  internal;
var
  regs: ring_$regs_ptr_t;
  status: integer;
begin
  with dma[channel] do begin
    regs := ring_$ctl[unit].device_info^.disk_dinit;
    status := ord(csr);
    if ((status & m68450_csr_act) <> 0)
       or else ((channel <> 2) and then (0 in regs^.rcv_csr)) then
      ccr := chr(m68450_ccr_sab)
    else if (status & m68450_csr_err) <> 0 then
      crash_system(status_$network_hardware_error);
    csr := chr(16#FF);
  end;
end;
%endif
