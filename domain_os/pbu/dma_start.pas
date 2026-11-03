{ PBU_$DMA_START - start a PBU unit's DMA transfer.

  Image addresses:
    sau3  0x00E89C44  PBU_$DMA_START
    sau5  0x00E92008  PBU_$DMA_START
    sau8  0x03CA574C  PBU_$DMA_START

  - On the AT bus (`pbu_atbus_units') one of the bus's DMA channels,
    0..7 but 4, is started (DMA_$START_NCHECK) for the unit's buffer;
    channels 4..7 count words.
  - The buffer: with options member 2 none (the unit gets attribute 0,
    the transfer address 0); with member 3 one in the bus's memory, at
    16#80000..16#FFFFF or 16#900000..16#FFFFFF; otherwise wired pages of
    the unit, physically contiguous and within 64 KB when there are
    several.  A one-page buffer that is not the bus's memory is not
    checked against the windows.
  - Members 0, 1 and 2 give the channel's mode 1, 2 and 4 (the last
    one given), 0 without them.
  - Otherwise not supported; nothing else is read.

  Status stored:
    dma_$start_ncheck's status, as pbu_map_dma_error makes it: the
      transfer was started, or not
    pbu_map_check_unit's status: the unit is not set up
    status_$pbu_not_supported: the unit is not on the AT bus, or always
      without `pbu_atbus_units'
    status_$pbu_illegal_dma_channel: channel is not 0..7, or is 4
    io_$attr_cntl's status: member 2, the attribute could not be set
    status_$pbu_bad_controller_memory_length: the pages cross a 64 KB
      boundary, length is over 16#8000, or the buffer runs past the
      bus's window
    status_$pbu_buffer_page_not_wired: a page is not the unit's
    status_$pbu_buffer_not_contiguous: the pages are not contiguous
    status_$pbu_buffer_not_mapped: member 3, the buffer is not mapped
    status_$pbu_invalid_iova: the bus memory is outside the windows
    status_$pbu_bad_dma_direction: direction is not 0 or 1
    status_$pbu_bad_parameter: options has a member of 4..15
}

%if pbu_atbus_units %then
procedure pbu_$dma_start(in unit: integer; in channel: integer;
                         in direction: integer;
                         in buffer: univ pbu_$buffer_t;
                         in length: pinteger;
                         in options: pbu_$dma_options_t;
                         out status: status_$t);
label
  start;
var
  dcte: pbu_$dcte_ptr_t;
  va: linteger;
  pa: linteger;
  start_pa: linteger;
  next_va: linteger;
  next_pa: linteger;
  limit: linteger;
  span: linteger;
  i: integer;
  old_attrs: io_$attr_t;
  dir: integer;
  mode: integer;
  count: integer;
  ch: 0..7;
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

  if 2 in options then begin
    io_$attr_cntl(dcte^.unit_info.io_unit, [0], old_attrs, status);
    if status.all <> status_$ok then
      return;
    dcte^.flags.attr_set := true;
    pa := 0;
  end
  else begin
    va := linteger(addr(buffer));
    pa := pbu_map_owned_ppn(unit, va) * 1024;
    if not (3 in options) and then
       (va div 1024 <> (length + va - 1) div 1024) and then (pa <> 0) then
    begin
      { Several pages: each the unit's, each after the last. }
      if ((pa & 16#FFFF0000) <> ((length + pa) & 16#FFFF0000)) or else
         (length > 16#8000) then begin
        status.all := status_$pbu_bad_controller_memory_length;
        return;
      end;
      start_pa := (va & 16#3FF) + pa;
      for i := 1 to (length + va - 1) div 1024 - va div 1024 do begin
        next_va := linteger(addr(buffer)) + i * 1024;
        next_pa := pbu_map_owned_ppn(unit, next_va) * 1024;
        if next_pa = 0 then begin
          status.all := status_$pbu_buffer_page_not_wired;
          return;
        end;
        if pa + 1024 <> next_pa then begin
          status.all := status_$pbu_buffer_not_contiguous;
          return;
        end;
        pa := next_pa;
      end;
      pa := start_pa;
      goto start;
    end;
    if pa = 0 then
      if 3 in options then begin
        pa := pbu_map_owned_ppn(unit, va) * 1024;
        if pa = 0 then begin
          status.all := status_$pbu_buffer_not_mapped;
          return;
        end;
      end
      else begin
        status.all := status_$pbu_buffer_page_not_wired;
        return;
      end;
    pa := pa + (va & 16#3FF);
    if (pa div 1024 <> (length + pa - 1) div 1024) or else (3 in options)
    then begin
      { The bus's memory windows. }
      if (pa >= 16#80000) and then (pa < 16#100000) then begin
        limit := 16#100000;
        span := length + 16#80000;
      end
      else if (pa >= 16#900000) and then (pa < 16#1000000) then begin
        limit := 16#1000000;
        span := length + 16#900000;
      end
      else begin
        status.all := status_$pbu_invalid_iova;
        return;
      end;
      if span > limit then begin
        status.all := status_$pbu_bad_controller_memory_length;
        return;
      end;
      if length + pa > limit then begin
        status.all := status_$pbu_invalid_iova;
        return;
      end;
    end;
  end;

start:
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
  if ch >= 4 then
    count := length div 2
  else
    count := length;
  dma_$start_ncheck(ch, count, pa, dir, mode, dma_status);
  status := dma_status;
  if status.all <> status_$ok then
    pbu_map_dma_error(status);
end;
%else
procedure pbu_$dma_start(in unit: integer; in channel: integer;
                         in direction: integer;
                         in buffer: univ pbu_$buffer_t;
                         in length: pinteger;
                         in options: pbu_$dma_options_t;
                         out status: status_$t);
begin
  status.all := status_$pbu_not_supported;
end;
%endif
