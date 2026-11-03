{ PBU_$GET_PTR - one of a PBU unit's addresses.

  Image addresses:
    sau3  0x00E59134  PBU_$GET_PTR
    sau5  0x00E59304  PBU_$GET_PTR
    sau8  0x03C61960  PBU_$GET_PTR

  - which selects the unit's user stack area (pbu_ptr_stack), its
    controller memory's address and length (pbu_ptr_assoc), or its CSR
    pages' address (pbu_ptr_csr).
  - pbu_ptr_diag is the address past the CSR pages and one more page (a
    fault's frame), pbu_ptr_dcte the DCTE and the DCTE's size.
  - A unit in use by another process passes too.  The result is unset
    when the check fails otherwise, or for a bad which.

  Status stored:
    pbu_check_unit's status: the address was returned, or the unit is
      not set up
    pbu_check_unit's status, its fail bit set: another process owns the
      unit
    status_$pbu_bad_parameter: which is none of these
}

function pbu_$get_ptr(in unit: integer; in which: integer;
                      out size: integer32;
                      out status: status_$t): univ_ptr;
var
  dcte: pbu_$dcte_ptr_t;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then begin
    if status.all <> status_$pbu_unit_in_use then
      return;
    status.fail := true;
  end;
  case which of
    pbu_ptr_stack: begin
      pbu_$get_ptr := dcte^.user_stack;
    end;
    pbu_ptr_assoc: begin
      pbu_$get_ptr := univ_ptr(dcte^.assoc_va);
      size := dcte^.assoc_length;
    end;
    pbu_ptr_csr: begin
      pbu_$get_ptr := univ_ptr(dcte^.csr_va);
    end;
    pbu_ptr_diag: begin
      pbu_$get_ptr := univ_ptr(dcte^.csr_pages * 1024 + dcte^.csr_va + 1024);
    end;
    pbu_ptr_dcte: begin
      pbu_$get_ptr := dcte;
      size := 84;
    end;
    otherwise begin
      status.all := status_$pbu_bad_parameter;
    end;
  end;
end;
