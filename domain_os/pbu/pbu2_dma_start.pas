{ PBU2_$DMA_START - start a PBU unit's DMA transfer.

  Image addresses:
    sau3  0x00E89C7C  PBU2_$DMA_START
    sau5  0x00E92040  PBU2_$DMA_START
    sau8  0x03CA5B02  PBU2_$DMA_START

  - On the AT bus (`pbu_atbus_units') PBU_$DMA_START with the same
    arguments but the fifth, which is not read, and the low word of the
    longword length.
  - Otherwise not supported; nothing else is read.

  Status stored:
    pbu_$dma_start's status: the transfer was started, or not
    status_$pbu_not_supported: always, without `pbu_atbus_units'
}

%if pbu_atbus_units %then
procedure pbu2_$dma_start(in unit: integer; in channel: integer;
                          in direction: integer;
                          in buffer: univ pbu_$buffer_t;
                          in unused_5: integer32; in length: integer32;
                          in options: pbu_$dma_options_t;
                          out status: status_$t);
begin
  pbu_$dma_start(unit, channel, direction, buffer,
                 pbu_$long_words_t(length).low, options, status);
end;
%else
procedure pbu2_$dma_start(in unit: integer; in channel: integer;
                          in direction: integer;
                          in buffer: univ pbu_$buffer_t;
                          in unused_5: integer32; in length: integer32;
                          in options: pbu_$dma_options_t;
                          out status: status_$t);
begin
  status.all := status_$pbu_not_supported;
end;
%endif
