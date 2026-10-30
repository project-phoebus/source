{ debug_clear_internal - detach a process from its debugger.

  Image addresses:
    sau2  0x00E41A24  debug_clear_internal (module-local)

  - The process leaves its debugger's target list; a zombie's guardian
    is woken, else with flag the creation record's byte at +0x90 is
    cleared (XPD_$WRITE) and the process resumed.  Every status is
    ignored.

  Status stored: none.
}

procedure debug_clear_internal(proc_idx: integer; flag: boolean);
var
  status: status_$t;
begin
  with proc2_$info_table[proc_idx] do begin
    if debugger_idx <> 0 then begin
      debug_unlink_from_list(proc_idx);
      flags.bits := flags.bits - [xpd_pf_suspended];
      if proc2_pf_zombie in flags.bits then
        proc2_$awaken_guardian(proc_idx)
      else if flag then begin
        xpd_$write(asid, proc2_cr_rec_ptr_t(cr_rec_2)^.debug_flag,
                   1, integer32(0), status);
        flags.bits := flags.bits - [xpd_pf_suspended];
        proc1_$resume(level1_pid, status);
      end;
    end;
  end;
end;
