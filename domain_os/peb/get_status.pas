{ PEB_$GET_STATUS - the status of the board's last exception.

  Image addresses:
    sau2  0x00E5ADCA  PEB_$GET_STATUS

  - The exception status is read from the private register page at
    16#7000, or from the command page PEB_$M_DCMD_PAGE when the pages
    are installed.

  Returns:
    status_$peb_fp_overflow .. status_$peb_unimplemented_opcode: the
      first exception bit set (bits 0..5, in the constants' order)
    status_$peb_interrupt: no bit set

  Status stored: none.
}

function peb_$get_status: integer32;
var
  regs: peb_$regs_ptr_t;
  st: status_$t;
  exc: integer32;
begin
  { the private page or the command page }
  if not peb_$info.mmu_installed then
    regs := peb_$regs_ptr_t(16#7000)
  else
    regs := addr(peb_$m_dcmd_page);

  exc := regs^.status;
  if (exc & 1) <> 0 then
    st.all := status_$peb_fp_overflow
  else if (exc & 2) <> 0 then
    st.all := status_$peb_fp_underflow
  else if (exc & 4) <> 0 then
    st.all := status_$peb_div_by_zero
  else if (exc & 8) <> 0 then
    st.all := status_$peb_fp_loss_of_significance
  else if (exc & 16#10) <> 0 then
    st.all := status_$peb_fp_hw_error
  else if (exc & 16#20) <> 0 then
    st.all := status_$peb_unimplemented_opcode
  else
    st.all := status_$peb_interrupt;

  peb_$get_status := st.all;
end;
