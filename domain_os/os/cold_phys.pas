{ cold_phys - the physical address of a kernel VA before the MMU is on.

  Image addresses:
    sau7  0x01002976  cold_phys (module-local)
    sau9  0x04003086  cold_phys (module-local)

  - The DUMP page (DUMP .. OS_PROC) is COLD's copy at 0x4001400; every
    other VA is the kernel's as loaded, OS_PROC at 0x4004400.  The
    compares are unsigned.
  - `cold_ram_16mb': DUMP's copy is at 0x1000C00 and OS_PROC at
    0x1003C00; the kernel past its first 0x54000 bytes is at
    MOVE_TO_PPN's pages (a signed compare of the offset).

  Status stored: none.
}

function cold_phys(in va: univ linteger): integer32; internal;
begin
  if (va < linteger(addr(os_proc))) and then
     (va >= linteger(addr(dump))) then
    cold_phys := va - linteger(addr(dump)) + os_cold_dump_pa
%if cold_ram_16mb %then
  else if va - linteger(addr(os_proc)) >= os_cold_kernel_low then
    cold_phys := va - linteger(addr(os_proc)) - os_cold_kernel_low +
                 move_to_ppn * 1024
  else
    cold_phys := va - linteger(addr(os_proc)) + os_cold_kernel_pa;
%else
  else
    cold_phys := va - linteger(addr(os_proc)) + os_cold_kernel_pa;
%endif
end;
