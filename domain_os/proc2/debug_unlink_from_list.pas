{ debug_unlink_from_list - take a process off its debugger's target list.

  Image addresses:
    sau2  0x00E418B0  debug_unlink_from_list (module-local)

  - The debugger's singly linked target list is walked for the process;
    one missing from it crashes the system (proc2_$uid_not_found).

  Status stored: none.
}

procedure debug_unlink_from_list(proc_idx: integer); internal;
var
  current_idx: integer;
  prev_idx: integer;
begin
  with proc2_$info_table[proc_idx]: entry do begin
    if entry.debugger_idx <> 0 then begin
      with proc2_$info_table[entry.debugger_idx]: debugger do begin

        entry.debugger_idx := 0;
        current_idx := debugger.first_debug_target_idx;
        prev_idx := 0;
        while current_idx <> 0 do begin
          if current_idx = proc_idx then begin
            if prev_idx = 0 then
              debugger.first_debug_target_idx :=
                entry.next_debug_target_idx
            else
              proc2_$info_table[prev_idx].next_debug_target_idx :=
                entry.next_debug_target_idx;
            return;
          end;
          prev_idx := current_idx;
          current_idx :=
            proc2_$info_table[prev_idx].next_debug_target_idx;

        end;
        crash_system(proc2_$uid_not_found);
      end;
    end;
  end;
end;
