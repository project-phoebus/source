{ GPU_$DIAG_RELEASE - leave the graphics processor's diagnostic mode.

  Image addresses:
    sau5  0x00E73FC4  GPU_$DIAG_RELEASE
    sau6  0x7807AF3C  GPU_$DIAG_RELEASE

  - Nothing is done unless in diagnostic mode, for the process that
    holds the processor.
  - The processor's registers are mapped back for the supervisor
    (protection 16#16) when MMU_$VTOP finds them.

  Status stored: none.
}

procedure gpu_$diag_release;
var
  pa: integer32;
  status: status_$t;
begin
  if diag_mode and then (gpu_$user_pid = proc1_$current) then begin
    gpu_$unwire_buffers;
    if diag_buf2_pa <> 0 then
      wp_$unwire(diag_buf2_pa);
    if diag_buf1_pa <> 0 then
      wp_$unwire(diag_buf1_pa);
    diag_buf2_pa := 0;
    diag_buf1_pa := 0;
    pa := mmu_$vtop(integer32(addr(gpu)), status);
    if status.all = status_$ok then
      mmu_$install(pa, addr(gpu), 0, 16#16);
    diag_mode := false;
    context_pid := 0;
    gpu_$unlock;
  end;
end;
