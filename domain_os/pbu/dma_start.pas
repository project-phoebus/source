{ PBU_$DMA_START - start a PBU unit's DMA transfer.

  Image addresses:
    sau3  0x00E89C44  PBU_$DMA_START
    sau5  0x00E92008  PBU_$DMA_START

  - Not supported on the SAU5; nothing else is read.

  Status stored:
    status_$pbu_not_supported: always
}

procedure pbu_$dma_start(in unit: integer; in arg_2: integer32;
                         in arg_3: integer32; in arg_4: integer32;
                         in arg_5: integer32; in arg_6: integer32;
                         out status: status_$t);
begin
  status.all := status_$pbu_not_supported;
end;
