{ PBU2_$UNMAP - unmap a buffer from a PBU unit's I/O map space.

  Image addresses:
    sau5  0x00E921AA  PBU2_$UNMAP

  - At interrupt level (PBU_$TRAP6); no lock.  The buffer's entries
    lose their valid bit (bit 15) when the first page's entry holds the
    buffer's first page.
  - Only the first page's entry is compared.

  Status stored:
    pbu_map_check_unit's status: the buffer was unmapped, or the unit is
      not set up
    status_$pbu_iomap_not_allocated: the unit has no map space
    status_$pbu_invalid_iova: iova is not inside the space with the
      length after it
    status_$pbu_buffer_not_mapped: the first page's entry is another
      page's
}

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
  entry_ppn := iomap[first] & 16#3FFF;
  not_mapped := pbu_map_owned_ppn(unit, va) <> entry_ppn;
  if not_mapped then begin
    status.all := status_$pbu_buffer_not_mapped;
    return;
  end;
  for k := first to first + npages - 1 do
    iomap[k] := iomap[k] & (-16#8001);
end;
