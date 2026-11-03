{ VTOP_OR_CRASH - translate a virtual address, crashing on failure.

  Image addresses:
    sau2  0x00E6D1E8  VTOP_OR_CRASH
    sau3  0x00E6D794  VTOP_OR_CRASH
    sau4  0x0F876CB0  VTOP_OR_CRASH
    sau5  0x00E6E8C4  VTOP_OR_CRASH
    sau8  0x03C76550  VTOP_OR_CRASH
    sau9  0x3C473DC4  VTOP_OR_CRASH

  - The OS module's own routine, not MMAP_UNWIRED's module-local
    mmu_$vtop_or_crash (mmu/vtop_or_crash.pas), which takes its address
    by value.

  Status stored: none.
}

function vtop_or_crash(va: integer32): integer32;
var
  status: status_$t;
  ppn: integer32;
begin
  ppn := mmu_$vtop(va, status);
  if status.all <> status_$ok then
    crash_system(status);
  vtop_or_crash := ppn;
end;
