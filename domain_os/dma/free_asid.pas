{ DMA_$FREE_ASID - free an address space's DMA state (nothing to do).

  Image addresses:
    sau2  0x00E0A454  DMA_$FREE_ASID
    sau5  0x00E0A328  DMA_$FREE_ASID

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure dma_$free_asid(asid: integer); options(val_param);
begin
end;
