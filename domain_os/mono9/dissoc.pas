{ MONO9_$DISSOC - dissociate the display from the current process.

  Image addresses:
    sau9  0x3C476F96  MONO9_$DISSOC

  - Only the owner gives the display up; the special segment leaves its
    address space when that is the current one.
  - Done under the SMD request lock.

  Status stored:
    status_$ok: always
}

procedure mono9_$dissoc(dcte: mono9_$dcte_ptr_t; out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do begin
    ml_$lock(ml_$smd_request_lock);
    if owner = proc1_$current then begin
      owner := 0;
      if (asid <> 0) and then (asid = proc1_$as_id) then
        mmu_$remove_special_seg(special_va, asid, 0);
    end;
    ml_$unlock(ml_$smd_request_lock);
  end;
  status.all := status_$ok;
end;
