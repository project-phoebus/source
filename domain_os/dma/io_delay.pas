{ dma_io_delay - a pause between two writes to the DMA controllers.

  Image addresses:
    sau7  0x3C4378BC  dma_io_delay (module-local)
    sau8  0x03C320BC  dma_io_delay (module-local)

  - An empty procedure: its call and return are the pause DMA_$INIT
    takes after each register write.  With `atbus_dma_iomap' it reads
    the CPU status register's word into dma_io_wait.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure dma_io_delay; internal;
begin
%if atbus_dma_iomap %then
  dma_io_wait := mmu.csr;
%endif
end;
