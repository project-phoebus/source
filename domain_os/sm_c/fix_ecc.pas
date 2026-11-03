{ sm_c_$fix_ecc - correct a data error with the controller's ECC.

  Image addresses:
    sau3  0x00E6EE44  sm_c_$fix_ecc (module-local)
    sau5  0x00E749A8  sm_c_$fix_ecc (module-local)

  - The request's page is mapped at SM_ECC_BUF for SM_FIX_ECC, then
    mapped back where it was (or unmapped), its used bit cleared.

  Status stored: none.
}

procedure sm_c_$fix_ecc; internal;
var
  old_va: integer32;
  ecc: sm_c_$ecc_words_t;
begin
  old_va := mmu_$ptov(sm_c_req^.ppn);
  mmu_$install(sm_c_req^.ppn, addr(sm_ecc_buf), 0, 16#16);
  ecc.w0 := lshft(sm_$cb.c_ecc.b0, 8) + sm_$cb.c_ecc.b1;
  ecc.w1 := lshft(sm_$cb.c_ecc.b3, 8) + sm_$cb.c_ecc.b2;
  sm_fix_ecc(sm_c_req^.header.l, sm_ecc_buf, ecc);
  if old_va <> 0 then
    mmu_$install(sm_c_req^.ppn, univ_ptr(old_va), 0, 16#16)
  else
    mmu_$remove(sm_c_req^.ppn);
  mmu_$clr_used(sm_c_req^.ppn);
end;
