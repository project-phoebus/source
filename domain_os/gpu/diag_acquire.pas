{ GPU_$DIAG_ACQUIRE - take the graphics processor for a diagnostic
  program.

  Image addresses:
    sau5  0x00E73EAE  GPU_$DIAG_ACQUIRE
    sau6  0x7807AE28  GPU_$DIAG_ACQUIRE

  - A process that holds the processor in diagnostic mode already only
    gets the addresses back.
  - buf1 is wired only when it is not nil and not buf2, buf2 when it is
    not nil; the processor's registers are mapped into the user space.
  - A failure unwires what was wired and gives the processor back.

  Status stored:
    status_$ok: the processor is held in diagnostic mode
    status_$gpu_not_initialized: the process did not open the processor
    gpu_$lock's status: the processor could not be taken
    mst_$wire's status: a buffer could not be wired
    mmu_$vtop's status: the processor's registers were not found
}

procedure gpu_$diag_acquire(in buf1: univ_ptr; in buf2: univ_ptr;
                            out gpu_va: univ_ptr; out buf1_pa: integer32;
                            out buf2_pa: integer32;
                            out status_ret: status_$t);
label
  10;
var
  pa: integer32;
begin
  if page_max[proc1_$current] <= 0 then begin
    status_ret.all := status_$gpu_not_initialized;
    return;
  end;

  if not ((gpu_$user_pid = proc1_$current) and diag_mode) then begin
    gpu_$lock(status_ret);
    if status_ret.all <> status_$ok then
      return;

    if (buf1 <> nil) and then (buf1 <> buf2) then begin
      pa := mst_$wire(integer32(buf1), status_ret);
      if status_ret.all <> status_$ok then
        goto 10;
      diag_buf1_pa := pa;
    end;
    if buf2 <> nil then begin
      pa := mst_$wire(integer32(buf2), status_ret);
      if status_ret.all <> status_$ok then
        goto 10;
      diag_buf2_pa := pa;
    end;

    pa := mmu_$vtop(integer32(addr(gpu)), status_ret);
    { the wire failures come to 10 too (a `goto' into this `then' part,
      legal without -iso, ref 4-95) }
    if status_ret.all <> status_$ok then begin
10:
      if diag_buf1_pa <> 0 then
        wp_$unwire(diag_buf1_pa);
      if diag_buf2_pa <> 0 then
        wp_$unwire(diag_buf2_pa);
      diag_buf1_pa := 0;
      diag_buf2_pa := 0;
      gpu_$unlock;
      return;
    end;
    mmu_$install(pa, addr(gpu), 0, 6);
    diag_mode := true;
  end;

  gpu_va := addr(gpu);
  buf1_pa := diag_buf1_pa;
  buf2_pa := diag_buf2_pa;
end;
