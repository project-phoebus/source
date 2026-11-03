{ IO_$UNMAP_CSR - unmap a unit's CSR pages.

  Image addresses:
    sau2  0x00E1A910  IO_$UNMAP_CSR
    sau3  0x00E199C0  IO_$UNMAP_CSR
    sau5  0x00E1AC70  IO_$UNMAP_CSR
    sau8  0x03C1BAAC  IO_$UNMAP_CSR
    sau9  0x3C41D464  IO_$UNMAP_CSR

  - The bus translates the pages' bus address and each page's mapping
    is removed; with `large_vm' each page's mapping is removed by its
    virtual address, and the bus is not asked.

  Status stored:
    status_$ok: always
}

procedure io_$unmap_csr(in req: io_$acquire_rec_t; out status: status_$t);
  options(val_param);
var
%if large_vm %then
  va: integer32;
%else
  ppn: integer32;
%endif
  i: integer;                             { the loop count }
begin
  if req.csr.has_csr then begin
%if large_vm %then
    va := req.csr.va;
    for i := 1 to req.csr.pages do begin
      mmu_$remove(univ_ptr(va), 0);
      va := va + 16#400;
    end;
%else
    ppn := io_$bus_epv[req.bus].xlate_iova^(req.csr.pa);
    for i := 1 to req.csr.pages do begin
      mmu_$remove(ppn);
      ppn := ppn + 1;
    end;
%endif
  end;

  status.all := status_$ok;
end;
