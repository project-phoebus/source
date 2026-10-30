{ DMA_$INIT - put the four DMA channels into their idle state.

  Image addresses:
    sau2  0x00E0A362  DMA_$INIT

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure dma_$init;
begin
  dma_$init_m68450_channel(addr(dma[3]), 3);
  dma_$init_m68450_channel(addr(dma[2]), 2);
  dma_$init_m68450_channel(addr(dma[0]), 0);
  dma_$init_m68450_channel(addr(dma[1]), 1);
end;
