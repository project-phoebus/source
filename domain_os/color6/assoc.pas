{ COLOR6_$ASSOC - map the board's registers into the current process.

  Image addresses:
    sau7  0x3C4839B2  COLOR6_$ASSOC

  - Unless the unit is the address space's already, its old association
    is dropped; the address space's mapping is shared by its units, made
    on the first: the special segment mapped (MST_$MAP_SPECIAL) and the
    four register pages installed in it.
  - va is the mapping's address.
  - Done under the SMD request lock.

  Status stored:
    status_$ok: the unit was the process's already, or was associated
    MST_$MAP_SPECIAL's status: the segment could not be mapped
}

procedure color6_$assoc(dcte: color6_$dcte_ptr_t; out va: univ_ptr;
                        out status: status_$t);
  options(val_param);
var
  info: color6_$info_ptr_t;
  st: status_$t;
  p: univ_ptr;
begin
  info := dcte^.info;
  st.all := status_$ok;
  ml_$lock(ml_$smd_request_lock);
  if info^.asid = proc1_$as_id then
    p := color6_$asid_map[proc1_$as_id].va
  else begin
    color6_release(info);
    if color6_$asid_map[proc1_$as_id].count <> 0 then
      p := color6_$asid_map[proc1_$as_id].va
    else begin
      p := mst_$map_special(color6_special_seg, 1, color6_special_uid,
                            proc1_$as_id, st);
      if st.all = status_$ok then begin
        mmu_$install_special(color6_$csr_ppn, p, proc1_$as_id,
                             color6_$user_prot);
        mmu_$install_special(color6_$fifo_ppn,
                             univ_ptr(integer32(p) + color6_$page_size),
                             proc1_$as_id, color6_$user_prot);
        mmu_$install_special(color6_$ctl1_ppn,
                             univ_ptr(integer32(p) + 2 * color6_$page_size),
                             proc1_$as_id, color6_$user_prot);
        mmu_$install_special(color6_$ctl2_ppn,
                             univ_ptr(integer32(p) + 3 * color6_$page_size),
                             proc1_$as_id, color6_$user_prot);
        color6_$asid_map[proc1_$as_id].va := p;
      end;
    end;
    if st.all = status_$ok then begin
      info^.asid := proc1_$as_id;
      info^.owner := proc1_$current;
      color6_$asid_map[proc1_$as_id].count :=
        color6_$asid_map[proc1_$as_id].count + 1;
    end;
  end;
  ml_$unlock(ml_$smd_request_lock);
  status := st;
  va := p;
end;
