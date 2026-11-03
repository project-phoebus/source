{ PCHIST_$UNIX_PROFIL_CNTL - turn per-process profiling on or off (UNIX
  profil).

  Image addresses:
    sau2  0x00E5CA58  PCHIST_$UNIX_PROFIL_CNTL
    sau4  0x0F866568  PCHIST_$UNIX_PROFIL_CNTL

  - Command 0 sets the process's profil() parameters and touches the
    buffer's first and last words under a cleanup handler (a fault
    returns); then the process is profiled, with PROC2's cleanup bit 11.
  - Command 1 undoes that for a profiled process; command 2 sets the
    process's overflow pointer.

  Status stored:
    status_$ok: always
}

procedure pchist_$unix_profil_cntl(in cmd_ptr: integer;
                                   in buffer_ptr: linteger;
                                   in bufsize_ptr: linteger;
                                   in offset_ptr: linteger;
                                   in scale_ptr: linteger;
                                   out status_ret: status_$t);
var
  rec: fim_$cleanup_rec_t;
  unused_1c: integer32;                   { stand-in }
  cleanup_status: status_$t;
  pid: integer;
  probe: integer;
  p: pchist_$word_ptr_t;
begin
  status_ret.all := status_$ok;
  pid := proc1_$current;

  case cmd_ptr of
    pchist_$profil_enable: begin
      with pchist_$proc_data[pid] do begin
        buffer := buffer_ptr;
        bufsize := bufsize_ptr;
        offset := offset_ptr;
        scale := scale_ptr;
        overflow_ptr := nil;
        cleanup_status := fim_$cleanup(rec);
        if cleanup_status.all = fault_$cleanup_set then begin
          p := pchist_$word_ptr_t(buffer);
          probe := p^;
          p := pchist_$word_ptr_t(integer32(p) + bufsize - 2);
          probe := p^;
          fim_$rls_cleanup(rec);
        end
        else begin
          fim_$pop_signal(rec);
          return;
        end;
      end;

      ml_$exclusion_start(pchist_$lock);
      if not pchist_$proc_bitmap[pid] then
        pchist_$proc_profiling_count := pchist_$proc_profiling_count + 1;
      pchist_$proc_bitmap[pid] := true;
      proc2_$set_cleanup(11);
      pchist_$addr[pid] := 0;
      pchist_$enable_terminal(0);
      ml_$exclusion_stop(pchist_$lock);
    end;

    pchist_$profil_disable: begin
      if pchist_$proc_bitmap[pid] then begin
        pchist_$addr[pid] := 0;
        ml_$exclusion_start(pchist_$lock);
        pchist_$proc_profiling_count := pchist_$proc_profiling_count - 1;
        pchist_$enable_terminal(1);
        ml_$exclusion_stop(pchist_$lock);
        pchist_$proc_bitmap[pid] := false;
      end;
    end;

    pchist_$profil_set_overflow: begin
      pchist_$proc_data[pid].overflow_ptr :=
        pchist_$lint_ptr_t(buffer_ptr);
    end;
  end;
end;
