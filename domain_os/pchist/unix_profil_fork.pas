{ PCHIST_$UNIX_PROFIL_FORK - give a forked child its parent's profiling.

  Image addresses:
    sau2  0x00E5CC32  PCHIST_$UNIX_PROFIL_FORK

  - Only when the current process is profiled: the child gets a copy of
    its parameters and its bitmap bit, counted (and the terminal manager
    told) when the bit was clear.

  Status stored: none.
}

procedure pchist_$unix_profil_fork(in child_pid_ptr: integer;
                                   in child_asid_p: integer);
var
  unused_4: integer32;                    { stand-in }
begin
  if pchist_$proc_bitmap[proc1_$current] then begin
    pchist_$proc_data[child_pid_ptr] := pchist_$proc_data[proc1_$current];
    pchist_$addr[child_pid_ptr] := 0;
    if not pchist_$proc_bitmap[child_pid_ptr] then begin
      ml_$exclusion_start(pchist_$lock);
      pchist_$proc_profiling_count := pchist_$proc_profiling_count + 1;
      pchist_$enable_terminal(0);
      ml_$exclusion_stop(pchist_$lock);
    end;
    pchist_$proc_bitmap[child_pid_ptr] := true;
  end;
end;
