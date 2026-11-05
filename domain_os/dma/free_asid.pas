{ DMA_$FREE_ASID - free an address space's DMA channels.

  Image addresses:
    sau2  0x00E0A454  DMA_$FREE_ASID
    sau5  0x00E0A328  DMA_$FREE_ASID
    sau7  0x3C40BA3E  DMA_$FREE_ASID
    sau8  0x03C0B0EA  DMA_$FREE_ASID

  - With the AT bus's DMA channels (`atbus_dma') every channel the
    address space has taken is freed, its terminal count cleared,
    without the DMA lock; otherwise nothing.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure dma_$free_asid(asid: integer); options(val_param);
%if atbus_dma %then
var
  channel: integer;
begin
  for channel := 0 to 7 do
    if dma_owner[channel] = asid then begin
      dma_owner[channel] := dma_free;
      if (dma_done & lshft(1, channel)) <> 0 then
        dma_done := dma_done - lshft(1, channel);
    end;
end;
%else
begin
end;
%endif
