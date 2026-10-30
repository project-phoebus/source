{ PBU_$DMA_STOP - stop a PBU unit's DMA transfer.

  Image addresses:
    sau5  0x00E9201A  PBU_$DMA_STOP

  - Not supported on the SAU5: the result is 0.
  - The frame holds 20 bytes no object addresses besides the result
    (unused_frame, a stand-in).

  Status stored:
    status_$pbu_not_supported: always
}

function pbu_$dma_stop(in unit: integer; in arg_2: integer32;
                       out status: status_$t): integer32;
var
  unused_frame: array[1..5] of integer32; { a stand-in }
begin
  status.all := status_$pbu_not_supported;
  pbu_$dma_stop := 0;
end;
