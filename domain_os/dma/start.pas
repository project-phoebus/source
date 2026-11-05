{ DMA_$START - start a DMA transfer for a buffer at a virtual address.

  Image addresses:
    sau7  0x3C40B634  DMA_$START
    sau8  0x03C0AD10  DMA_$START

  - The count must be 1..1024 bytes and stay within the address's page;
    the page's physical address (MMU_$VTOP) plus the offset goes to
    DMA_$START_NCHECK with the rest of the arguments.
  - With `atbus_dma_iomap' nothing is started: the transfers reach
    memory through the I/O map, and a caller maps its pages and calls
    DMA_$START_NCHECK.

  Status stored:
    status_$dma_start_not_supported: with `atbus_dma_iomap', always
    dma_$start_ncheck's status: the transfer was started, or not
    status_$dma_illegal_channel: channel is not 0..7
    status_$dma_illegal_byte_count: count is not 1..1024, or the buffer
      crosses its page's end
    mmu_$vtop's status: the address is not mapped
}

[section(wired_proc, wired_data)]
procedure dma_$start(channel: integer; count: integer; va: integer32;
                     direction: integer; mode: integer;
                     out status: status_$t);
  options(val_param);
var
  ppn: integer32;                         { with `atbus_dma_iomap' unused:
                                            the other form's page }
begin
%if atbus_dma_iomap %then
  status.all := status_$dma_start_not_supported;
%else
  if (channel < 0) or else (channel > 7) then
    status.all := status_$dma_illegal_channel
  else if (count <= 0) or else (count > 1024) or else
          (count + (va & 16#3FF) > 1024) then
    status.all := status_$dma_illegal_byte_count
  else begin
    ppn := mmu_$vtop(va, status);
    if status.all = status_$ok then
      dma_$start_ncheck(channel, count, ppn * 1024 + (va & 16#3FF),
                        direction, mode, status);
  end;
%endif
end;
