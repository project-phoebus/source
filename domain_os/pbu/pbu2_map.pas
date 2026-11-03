{ PBU2_$MAP - map a wired buffer in a PBU unit's I/O map space.

  Image addresses:
    sau3  0x00E89CA4  PBU2_$MAP
    sau5  0x00E92068  PBU2_$MAP
    sau8  0x03CA5B46  PBU2_$MAP

  - At interrupt level, from a user handler (PBU_$TRAP6); no lock.
  - Each page's I/O map entry is the page number plus the unit's
    control: a longword (`long_iomap'), else a word and the high word.
  - The result is iova plus the buffer's offset in its page, unset when
    a check fails.
  - The fit test compares an offset with the space's end address; the
    page found not wired keeps its entry (page 0 with the control's
    bits).
  - Without the I/O map space (`io_regions') nothing is mapped: the
    result is 0.

  Status stored:
    status_$ok: the buffer was mapped
    pbu_map_check_unit's status: the unit is not set up
    status_$pbu_iomap_not_allocated: the unit has no map space
    status_$pbu_invalid_iova: iova is not a page inside the space with
      the length after it
    status_$pbu_buffer_too_large: the buffer does not fit from its
      offset in its page
    status_$pbu_buffer_page_not_wired: a page is not wired for the unit
      (the entries before it invalidated)
    status_$ok: always, without `io_regions'
}

%if io_regions %then
function pbu2_$map(in unit: integer; in buffer: univ pbu_$buffer_t;
                   in length: linteger; in iova: linteger;
                   out status: status_$t): integer32;
var
  dcte: pbu_$dcte_ptr_t;
  offset: integer32;
  va: linteger;
  page_offset: integer;
  npages: integer32;
  first: integer;
  last: integer;
  slot: integer;
  k: integer;
  ctl: pbu_$ctl_t;
begin
  status.all := status_$ok;
  dcte := pbu_map_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if not dcte^.flags.map_allocated then begin
    status.all := status_$pbu_iomap_not_allocated;
    return;
  end;
  offset := iova - dcte^.map_start;
  if (offset < 0) or else (iova + length > dcte^.map_end) or else
     ((offset & 16#3FF) <> 0) then begin
    status.all := status_$pbu_invalid_iova;
    return;
  end;
  va := linteger(addr(buffer));
  page_offset := va & 16#3FF;
  if page_offset + offset + length > dcte^.map_end then begin
    status.all := status_$pbu_buffer_too_large;
    return;
  end;
  npages := (va + length - 1) div 1024 - va div 1024;
  first := linteger(offset) div 1024 + dcte^.map_page;
  ctl := dcte^.ctl;
  last := first + npages;
  for slot := first to last do begin
%if long_iomap %then
    iomap[slot] := pbu_map_owned_ppn(unit, va) + ctl.all;
    if (iomap[slot] & 16#3FFF) = 0 then begin
      for k := first to slot - 1 do
        iomap[k] := iomap[k] & (-16#8001);
%else
    iomap[slot].entry := pbu_map_owned_ppn(unit, va) + ctl.entry;
    if (iomap[slot].entry & 16#FFF) = 0 then begin
      for k := first to slot - 1 do
        iomap[k].entry := iomap[k].entry & 16#7FFF;
%endif
      status.all := status_$pbu_buffer_page_not_wired;
      return;
    end;
    va := va + 1024;
  end;
  pbu2_$map := page_offset + iova;
end;
%else
function pbu2_$map(in unit: integer; in buffer: univ pbu_$buffer_t;
                   in length: linteger; in iova: linteger;
                   out status: status_$t): integer32;
begin
  status.all := status_$ok;
  pbu2_$map := 0;
end;
%endif
