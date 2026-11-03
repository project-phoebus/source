{ mmu_$vtop_or_crash - translate a virtual address, crashing on failure.

  Image addresses:
    sau2  0x00E3190C  mmu_$vtop_or_crash (module-local)
    sau8  0x03C34CB4  mmu_$vtop_or_crash (module-local)
    sau9  0x3C4379F8  mmu_$vtop_or_crash (module-local)

  - A fragment of the MMAP_UNWIRED module (mmap/mmap_unwired.pas).
  - An MMU_$VTOP failure crashes the system.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function mmu_$vtop_or_crash(va: integer32): integer32; internal;
var
  status: status_$t;
begin
  mmu_$vtop_or_crash := mmu_$vtop(va, status);

  if status.all <> status_$ok then
    crash_system(status);
end;
