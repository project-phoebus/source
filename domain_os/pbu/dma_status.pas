{ PBU_$DMA_STATUS - a PBU unit's DMA transfer's status.

  Image addresses:
    sau5  0x00E9202E  PBU_$DMA_STATUS

  - Not supported on the SAU5; nothing else is read.

  Status stored:
    status_$pbu_not_supported: always
}

procedure pbu_$dma_status(in unit: integer; in arg_2: integer32;
                          out status: status_$t);
begin
  status.all := status_$pbu_not_supported;
end;
