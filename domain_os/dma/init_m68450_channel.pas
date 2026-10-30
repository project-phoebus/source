{ dma_$init_m68450_channel - put one MC68450 channel into its idle state.

  Image addresses:
    sau2  0x00E0A328  dma_$init_m68450_channel (module-local)

  - The channel is aborted and its status cleared; its priority is the
    channel number.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure dma_$init_m68450_channel(chan_virtual_address: dma_$m68450_channel_ptr_t;
                                   channel_number: integer); internal;
begin
  chan_virtual_address^.ccr := chr(m68450_ccr_sab);
  chan_virtual_address^.csr := chr(16#FF);
  chan_virtual_address^.dcr := chr(16#28);
  chan_virtual_address^.scr := chr(4);
  chan_virtual_address^.cpr := chr(channel_number);
end;
