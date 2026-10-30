{ cold_phys - the physical address of a kernel VA before the MMU is on.

  Image addresses:
    sau9  0x04003086  cold_phys (module-local)

  - The DUMP page (DUMP .. OS_PROC) is COLD's copy at 0x4001400; every
    other VA is the kernel's as loaded, OS_PROC at 0x4004400.  The
    compares are unsigned.

  Status stored: none.
}

function cold_phys(in va: univ linteger): integer32; internal;
begin
  if (va < linteger(addr(os_proc))) and then
     (va >= linteger(addr(dump))) then
    cold_phys := va - linteger(addr(dump)) + os_cold_dump_pa
  else
    cold_phys := va - linteger(addr(os_proc)) + os_cold_kernel_pa;
end;
