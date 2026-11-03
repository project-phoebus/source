{ dma_io_delay - a pause between two writes to the DMA controllers.

  Image addresses:
    sau8  0x03C320BC  dma_io_delay (module-local)

  - An empty procedure: its call and return are the pause DMA_$INIT
    takes after each register write.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure dma_io_delay; internal;
begin
end;
