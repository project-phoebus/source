{ PBU2_$UNMAP - unmap a buffer from a PBU unit's I/O map space.

  Image addresses:
    sau3  0x00E89DE0  PBU2_$UNMAP
    sau4  0x0F897D76  PBU2_$UNMAP
    sau5  0x00E921AA  PBU2_$UNMAP
    sau8  0x03CA5B56  PBU2_$UNMAP

  - At interrupt level (PBU_$TRAP6); no lock.  The buffer's entries
    lose their valid bit (bit 15) when the first page's entry holds the
    buffer's first page (14 bits, 12 of a word entry); word entries
    (`word_iomap') are cleared.
  - Only the first page's entry is compared.
  - Without the I/O map space (`io_regions') nothing is unmapped.

  Status stored:
    pbu_map_check_unit's status: the buffer was unmapped, or the unit is
      not set up
    status_$pbu_iomap_not_allocated: the unit has no map space
    status_$pbu_invalid_iova: iova is not inside the space with the
      length after it
    status_$pbu_buffer_not_mapped: the first page's entry is another
      page's
    status_$ok: always, without `io_regions'
}

%if io_regions %then
procedure pbu2_$unmap(in unit: integer; in buffer: univ pbu_$buffer_t;
                      in length: linteger; in iova: linteger;
                      out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
  iv: linteger;
  va: linteger;
  offset: integer32;
  npages: integer;
  first: integer;
  k: integer;
  entry_ppn: integer32;
  not_mapped: boolean;
begin
  dcte := pbu_map_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if not dcte^.flags.map_allocated then begin
    status.all := status_$pbu_iomap_not_allocated;
    return;
  end;
  iv := iova;
  va := linteger(addr(buffer));
  offset := iv - dcte^.map_start;
  if (offset < 0) or else (iv + length > dcte^.map_end) or else
     ((offset & 16#3FF) <> (va & 16#3FF)) then begin
    status.all := status_$pbu_invalid_iova;
    return;
  end;
  npages := (va + length - 1) div 1024 - va div 1024 + 1;
  first := linteger(offset) div 1024 + dcte^.map_page;
%if long_iomap %then
  entry_ppn := iomap[first] & 16#3FFF;
%elseif word_iomap %then
  entry_ppn := iomap[first] & 16#3FFF;
%else
  entry_ppn := iomap[first].entry & 16#FFF;
%endif
  not_mapped := pbu_map_owned_ppn(unit, va) <> entry_ppn;
  if not_mapped then begin
    status.all := status_$pbu_buffer_not_mapped;
    return;
  end;
  for k := first to first + npages - 1 do
%if long_iomap %then
    iomap[k] := iomap[k] & (-16#8001);
%elseif word_iomap %then
    iomap[k] := 0;
%else
    iomap[k].entry := iomap[k].entry & 16#7FFF;
%endif
end;
%else
procedure pbu2_$unmap(in unit: integer; in buffer: univ pbu_$buffer_t;
                      in length: linteger; in iova: linteger;
                      out status: status_$t);
begin
  status.all := status_$ok;
end;
%endif
