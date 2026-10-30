{ IO_$MAP_CSR - map a unit's CSR pages into the kernel's address space.

  Image addresses:
    sau2  0x00E1A894  IO_$MAP_CSR
    sau5  0x00E1ABF2  IO_$MAP_CSR
    sau9  0x3C41D3E6  IO_$MAP_CSR

  - The bus translates the pages' bus address; each 1024-byte page is
    installed at its virtual address (address space 0, protection 16#16)
    and made uncached.

  Status stored:
    status_$ok: always
}

procedure io_$map_csr(in req: io_$acquire_rec_t; out status: status_$t);
  options(val_param);
var
  va: integer32;
  ppn: integer32;
  i: integer;                             { the loop count }
begin
  if req.csr.has_csr then begin
    va := req.csr.va;
    ppn := io_$bus_epv[req.bus].xlate_iova^(req.csr.pa);
    for i := 1 to req.csr.pages do begin
      mmu_$install(ppn, univ_ptr(va), 0, 16#16);
      mmu_$cache_inhibit_va(univ_ptr(va));
      ppn := ppn + 1;
      va := va + 16#400;
    end;
  end;

  status.all := status_$ok;
end;
