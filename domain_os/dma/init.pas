{ DMA_$INIT - put the DMA channels into their idle state.

  Image addresses:
    sau2  0x00E0A362  DMA_$INIT
    sau8  0x03C320BE  DMA_$INIT

  - The MC68450's four channels; with the AT bus's DMA channels
    (`atbus_dma') both controllers are cleared and every channel masked
    and set to single mode, but channel 4, which cascades the first
    controller and is unmasked; no channel has a terminal count seen.
    A call of dma_io_delay follows each register write.

  Status stored: none.
}

%if atbus_dma %then
[section(os_init_proc, os_init_data)]
procedure dma_$init;
begin
  dma.master_clear1 := 0;
  dma_io_delay;
  dma.master_clear2 := 0;
  dma_io_delay;
  dma.cmd_status1 := 0;
  dma_io_delay;
  dma.cmd_status2 := 0;
  dma_io_delay;
  dma.all_mask1 := 15;
  dma_io_delay;
  dma.all_mask2 := 15;
  dma_io_delay;
  dma.mode1 := dma_mode_single + 0;
  dma_io_delay;
  dma.mode1 := dma_mode_single + 1;
  dma_io_delay;
  dma.mode1 := dma_mode_single + 2;
  dma_io_delay;
  dma.mode1 := dma_mode_single + 3;
  dma_io_delay;
  dma.mode2 := dma_mode_cascade + 0;
  dma_io_delay;
  dma.mode2 := dma_mode_single + 1;
  dma_io_delay;
  dma.mode2 := dma_mode_single + 2;
  dma_io_delay;
  dma.mode2 := dma_mode_single + 3;
  dma_io_delay;
  dma.mask2 := 0;
  dma_done := 0;
end;
%else
[section(wired_proc, wired_data)]
procedure dma_$init;
begin
  dma_$init_m68450_channel(addr(dma[3]), 3);
  dma_$init_m68450_channel(addr(dma[2]), 2);
  dma_$init_m68450_channel(addr(dma[0]), 0);
  dma_$init_m68450_channel(addr(dma[1]), 1);
end;
%endif
