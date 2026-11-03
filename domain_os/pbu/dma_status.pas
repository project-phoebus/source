{ PBU_$DMA_STATUS - a PBU unit's DMA transfer's status.

  Image addresses:
    sau3  0x00E89C6A  PBU_$DMA_STATUS
    sau5  0x00E9202E  PBU_$DMA_STATUS
    sau8  0x03CA5AA2  PBU_$DMA_STATUS

  - On the AT bus (`pbu_atbus_units') the status of the unit's channel
    (DMA_$STATUS), a DMA status made the PBU's (pbu_map_dma_error).
  - Otherwise not supported; nothing else is read.

  Status stored:
    pbu_map_check_unit's status: the transfer is done, or the unit is
      not set up
    status_$pbu_not_supported: the unit is not on the AT bus, or always
      without `pbu_atbus_units'
    dma_$status's status, as pbu_map_dma_error makes it: the transfer is
      not done
}

%if pbu_atbus_units %then
procedure pbu_$dma_status(in unit: integer; in channel: integer;
                          out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
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
  dma_$status(ch, dma_status);
  status := dma_status;
  if status.all <> status_$ok then
    pbu_map_dma_error(status);
end;
%else
procedure pbu_$dma_status(in unit: integer; in channel: integer;
                          out status: status_$t);
begin
  status.all := status_$pbu_not_supported;
end;
%endif
