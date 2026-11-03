{ PBU_$DMA_STOP - stop a PBU unit's DMA transfer.

  Image addresses:
    sau3  0x00E89C56  PBU_$DMA_STOP
    sau5  0x00E9201A  PBU_$DMA_STOP
    sau8  0x03CA5A2C  PBU_$DMA_STOP

  - On the AT bus (`pbu_atbus_units') the unit's channel is stopped
    (DMA_$STOP); the result is the count it leaves, unset when a check
    fails, and a DMA status becomes the PBU's (pbu_map_dma_error).
  - Otherwise not supported: the result is 0.  The frame holds 20 bytes
    no object addresses besides the result (unused_frame, a stand-in).

  Status stored:
    pbu_map_check_unit's status: the channel was stopped, or the unit
      is not set up
    status_$pbu_not_supported: the unit is not on the AT bus, or always
      without `pbu_atbus_units'
    dma_$stop's status, as pbu_map_dma_error makes it: the channel could
      not be stopped
}

%if pbu_atbus_units %then
function pbu_$dma_stop(in unit: integer; in channel: integer;
                       out status: status_$t): integer32;
var
  dcte: pbu_$dcte_ptr_t;
  residue: integer32;
  dma_status: status_$t;
  ch: integer;
begin
  dcte := pbu_map_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if dcte^.unit_info.bus <> io_$bus_atbus then begin
    status.all := status_$pbu_not_supported;
    return;
  end;
  ch := channel;
  dma_$stop(ch, residue, dma_status);
  pbu_$dma_stop := residue;
  status := dma_status;
  if status.all <> status_$ok then
    pbu_map_dma_error(status);
end;
%else
function pbu_$dma_stop(in unit: integer; in channel: integer;
                       out status: status_$t): integer32;
var
  unused_frame: array[1..5] of integer32; { a stand-in }
begin
  status.all := status_$pbu_not_supported;
  pbu_$dma_stop := 0;
end;
%endif
