{ MONO9_$ASSOC - associate the display with the current process.

  Image addresses:
    sau9  0x3C476E92  MONO9_$ASSOC

  - Unless the current process owns the display, its special segment
    is mapped here and the two control pages installed in it.
  - va is the segment's address, the old one when nothing is mapped.
  - The previous owner's address space (another process's, not this
    one) loses its special segment.
  - Done under the SMD request lock.

  Status stored:
    status_$ok: the display was the process's already, or was associated
    MST_$MAP_SPECIAL's status: the segment could not be mapped
}

procedure mono9_$assoc(dcte: mono9_$dcte_ptr_t; out va: univ_ptr;
                       out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do begin
    status.all := status_$ok;
    va := special_va;
    ml_$lock(ml_$smd_request_lock);
    if (owner <> proc1_$current) or else (owner = 0) then begin
      va := mst_$map_special(special_seg, 1, special_uid, proc1_$as_id,
                             status);
      if status.all = status_$ok then begin
        mmu_$install_special(mono9_$ctl_ppn_1, va, proc1_$as_id,
                             mono9_$ctl_prot);
        mmu_$install_special(mono9_$ctl_ppn_2,
                             univ_ptr(integer32(va) + mono9_$ctl_page_size),
                             proc1_$as_id, mono9_$ctl_prot);
        if (owner <> 0) and then (owner <> proc1_$current) and then
           (asid <> 0) and then (asid <> proc1_$as_id) then
          mmu_$remove_special_seg(special_va, asid, 0);
        asid := proc1_$as_id;
        owner := proc1_$current;
        special_va := va;
      end;
    end;
    ml_$unlock(ml_$smd_request_lock);
  end;
end;
