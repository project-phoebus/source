{ PBU2_$DMA_STOP - stop a PBU unit's DMA transfer.

  Image addresses:
    sau5  0x00E92052  PBU2_$DMA_STOP

  - PBU_$DMA_STOP with the same arguments, its result the result.

  Status stored:
    pbu_$dma_stop's status: always
}

function pbu2_$dma_stop(in unit: integer; in arg_2: integer32;
                        out status: status_$t): integer32;
begin
  pbu2_$dma_stop := pbu_$dma_stop(unit, arg_2, status);
end;
