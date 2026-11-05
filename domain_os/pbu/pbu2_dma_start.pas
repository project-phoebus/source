{ PBU2_$DMA_START - start a PBU unit's DMA transfer.

  Image addresses:
    sau3  0x00E89C7C  PBU2_$DMA_START
    sau5  0x00E92040  PBU2_$DMA_START
    sau6  0x780A743C  PBU2_$DMA_START
    sau7  0x3C4B6BCC  PBU2_$DMA_START
    sau8  0x03CA5B02  PBU2_$DMA_START

  - On the AT bus (`pbu_atbus_units') PBU_$DMA_START with the same
    arguments but the fifth, which is not read, and the low word of the
    longword length.
  - With the DMA through the I/O map space (`pbu_dma_iomap') the
    transfer starts at iova, a bus address of the unit's map space
    (PBU2_$MAP's result), which with its length must lie inside the
    space; with options member 2 iova is not checked, and the unit gets
    attribute 0 after the start.  A start that succeeds sets the unit's
    attr_set.  buffer is not read.
  - Otherwise not supported; nothing else is read.

  Status stored:
    pbu_$dma_start's status: the transfer was started, or not
    dma_$start_ncheck's status, as pbu_map_dma_error makes it: the
      transfer was started, or not (`pbu_dma_iomap', as the rest)
    pbu_map_check_unit's status: the unit is not set up
    status_$pbu_not_supported: the unit is not on the AT bus
    status_$pbu_illegal_dma_channel: channel is not 0..7, or is 4
    status_$pbu_iomap_not_allocated: the unit has no map space
    status_$pbu_invalid_iova: iova is outside the space
    status_$pbu_bad_controller_memory_length: the transfer runs to the
      space's end
    status_$pbu_bad_dma_direction: direction is not 0 or 1
    status_$pbu_bad_parameter: options has a member of 4..15
    io_$attr_cntl's status: member 2, the attribute could not be set
    status_$pbu_not_supported: always, without `pbu_atbus_units'
}

%if pbu_dma_iomap %then
procedure pbu2_$dma_start(in unit: integer; in channel: integer;
                          in direction: integer;
                          in buffer: univ pbu_$buffer_t;
                          in iova: integer32; in length: integer32;
                          in options: pbu_$dma_options_t;
                          out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
  dir: integer;
  mode: integer;
  ch: 0..7;
  count: integer;
  pa: linteger;
  old_attrs: io_$attr_t;
  dma_status: status_$t;
begin
  dcte := pbu_map_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if dcte^.unit_info.bus <> io_$bus_atbus then begin
    status.all := status_$pbu_not_supported;
    return;
  end;
  if (channel < 0) or else (channel > 7) or else (channel = 4) then begin
    status.all := status_$pbu_illegal_dma_channel;
    return;
  end;
  if not (2 in options) then begin
    { The bus address in the unit's map space. }
    if not dcte^.flags.map_allocated then begin
      status.all := status_$pbu_iomap_not_allocated;
      return;
    end;
    if (linteger(iova) < linteger(dcte^.map_start)) or else
       (linteger(iova) >= dcte^.map_end) then begin
      status.all := status_$pbu_invalid_iova;
      return;
    end;
    if linteger(iova) + linteger(length) >= dcte^.map_end then begin
      status.all := status_$pbu_bad_controller_memory_length;
      return;
    end;
  end;
  if direction = 0 then
    dir := 0
  else if direction = 1 then
    dir := 1
  else begin
    status.all := status_$pbu_bad_dma_direction;
    return;
  end;
  mode := 0;
  if 0 in options then
    mode := 1;
  if 1 in options then
    mode := 2;
  if 2 in options then
    mode := 4;
  if options * [4..15] <> [] then begin
    status.all := status_$pbu_bad_parameter;
    return;
  end;
  ch := channel;
  pa := iova;
  if ch >= 4 then
    count := linteger(length) div 2
  else
    count := pbu_$long_words_t(length).low;
  dma_$start_ncheck(ch, count, pa, dir, mode, dma_status);
  status := dma_status;
  if status.all <> status_$ok then
    pbu_map_dma_error(status)
  else if 2 in options then
    io_$attr_cntl(dcte^.unit_info.io_unit, [0], old_attrs, status);
  if status.all = status_$ok then
    dcte^.flags.attr_set := true;
end;
%elseif pbu_atbus_units %then
procedure pbu2_$dma_start(in unit: integer; in channel: integer;
                          in direction: integer;
                          in buffer: univ pbu_$buffer_t;
                          in iova: integer32; in length: integer32;
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
                          in iova: integer32; in length: integer32;
                          in options: pbu_$dma_options_t;
                          out status: status_$t);
begin
  status.all := status_$pbu_not_supported;
end;
%endif
