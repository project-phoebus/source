{ PROC2_$SET_VALID - mark the current process valid at its start.

  Image addresses:
    sau2  0x00E73484  PROC2_$SET_VALID

  - An entry with no stack file maps one (MST_$MAP_AREA_AT; a failure
    deletes the process); under ml_$proc2_lock member 7 of its flags is
    set.
  - An orphan not vforked fills its creation record: UIDs, the stack UID,
    the UNIX id, whether a debugger is attached.

  Status stored: none.
}

{ TODO(pascal) PROC2_$SET_VALID's frame has 4 bytes no declared object
  explains.  The image's is 4 bytes more than dpc's frame for the routine's
  locals and its `with' (0x10); nothing addresses any of the frame.  A
  stand-in (unused_10) keeps the size.  A lead, not settled: the second clear
  holds its array's address, the first in no saved register, which a pointer
  local to block_2 (4 bytes, register-held) would explain. }

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$set_valid;
var
  idx: integer;
  cr: proc2_cr_rec_ptr_t;
  i: integer;                             { the loops' count }
  unused_10: integer32;                   { nothing addressed: the
                                            TODO(pascal) above }
begin
  idx := proc2_$pid_to_index[proc1_$current];
  with proc2_$info_table[idx] do begin
    cr := proc2_cr_rec_ptr_t(cr_rec_2);
    if stack_uid.high = uid_$nil.high then begin
      cr^.addr_lo := as_$info.stack_file_low;
      cr^.size := as_$info.init_stack_file_size;
      mst_$map_area_at(cr^.addr_lo, cr^.size, 16#4000, true, stack_uid,
                       cr^.status);
      if cr^.status.all <> status_$ok then
        proc2_$delete;
      cr^.stack_uid := stack_uid;
    end;
    ml_$lock(ml_$proc2_lock);
    flags.bits := flags.bits + [xpd_pf_debug_target];
    ml_$unlock(ml_$proc2_lock);
    if (proc2_pf_orphan in flags.bits)
       and then not (proc2_pf_alt_asid in flags.bits) then begin

      cr^.proc_uid := proc2_$uid[proc1_$as_id];
      cr^.upid_b8 := upid;
      cr^.parent_uid := parent_uid;
      cr^.stack_uid := stack_uid;
      cr^.cpu_time.high := 0;
      cr^.cpu_time.low := 0;
      cr^.counts.stat2 := 0;
      cr^.counts.stat1 := 0;
      cr^.counts.field_10 := 0;
      cr^.debug_flag := false;
      cr^.b_c8 := 0;
      cr^.count_c6 := 1;
      if 3 in cr^.flags_c5 then
        cr^.debugger_uid := proc2_$uid[parent_pgroup_idx];
      cr^.debug_flag := debugger_idx <> 0;
      for i := 1 to 14 do
        cr^.block_1[i] := 0;
      for i := 1 to 14 do
        cr^.block_2[i] := 0;
    end;
  end;
end;
