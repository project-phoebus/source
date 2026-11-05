{ MONO_$ASSOC_CSRS - map the board's registers into the current
  process.

  Image addresses:
    sau7  0x3C484494  MONO_$ASSOC_CSRS
    sau8  0x03C79D40  MONO_$ASSOC_CSRS

  - When the current process in its current address space has them
    already, va is where they are.
  - Otherwise the special segment is mapped here and the CSR page and the
    next installed in it; the previous owner's address space (another
    process's, another space) loses its special segment.

  Status stored:
    MST_$MAP_SPECIAL's status: the segment was mapped, or could not be;
      not stored when the registers were the process's already
}

procedure mono_$assoc_csrs(dcte: mono_$dcte_ptr_t; out va: univ_ptr;
                             out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do
    if (proc1_$current = owner) and then (proc1_$as_id = asid) then
      va := special_va
    else begin
      va := mst_$map_special(special_seg, 1, special_uid, proc1_$as_id,
                             status);
      if status.all = status_$ok then begin
        mmu_$install_special(csr_ppn, va, proc1_$as_id, mono_$user_prot);
        mmu_$install_special(csr_ppn + 1,
                             univ_ptr(integer32(va) + mono_$page_size),
                             proc1_$as_id, mono_$user_prot);
        if (owner <> 0) and then (owner <> proc1_$current) and then
           (asid <> 0) and then (asid <> proc1_$as_id) then
          mmu_$remove_special_seg(special_va, asid, 0);
        asid := proc1_$as_id;
        owner := proc1_$current;
        special_va := va;
      end;
    end;
end;
