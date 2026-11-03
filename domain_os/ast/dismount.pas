{ AST_$DISMOUNT - deactivate every object on a volume and dismount its
  VTOC.

  Image addresses:
    sau2  0x00E069CA  AST_$DISMOUNT
    sau4  0x0F806D66  AST_$DISMOUNT
    sau9  0x3C407C58  AST_$DISMOUNT

  - Under the AST lock the volume is marked as dismounting and the
    routine waits until no activation is in progress on it.
  - Each local AOTE on the volume (not a canned object, not the paging
    file) is deactivated and released.  A failure skips VTOC_$DISMOUNT
    and records the AOTE in AST_$DISMOUNT_FAILED_PTR.

  Status stored:
    status_$ok: the volume was dismounted
    ast_$process_aote's status: a deactivation failed
    vtoc_$dismount's status: the VTOC dismount failed
}

procedure ast_$dismount(vol_index: integer; force: boolean;
                        out status: status_$t);
label
  10, 20;
var
  local_status: status_$t;
  aote: ast_$aote_ptr_t;
  wait_val: integer32;
begin
  local_status.all := status_$ok;
  proc1_$inhibit_begin;
  ml_$lock(ml_$ast_lock);

  ast_$vol_info_count := ast_$vol_info_count + [vol_index];
  ast_$dism_seqn := ast_$dism_seqn + 1;

  { no activation in progress on the volume }
  while ast_$vol_indices[vol_index] <> 0 do begin
    wait_val := ast_$dism_ec.value + 1;
    ml_$unlock(ml_$ast_lock);
    discard(ec_$wait(addr(ast_$dism_ec), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), wait_val, 0, 0));
    ml_$lock(ml_$ast_lock);
  end;

  { the whole AOT }
  aote := addr(aot);
  while aote <> ast_$aote_limit do begin
    if not aote^.loc.remote and then (aote^.vol_index = vol_index) then
    begin
      if 7 in aote^.flags then begin
        ast_$wait_for_ast_intrans;
        goto 10;
      end;
      if (ast_uid_bytes_t(aote^.uid).first <> 0)
         and then (aote^.uid <> network_$paging_file_uid) then begin
        ast_$process_aote(aote^, force, true, true,
                          local_status);
        if local_status.all <> status_$ok then begin
          ml_$unlock(ml_$ast_lock);
          ast_$dismount_failed_ptr := aote;
          goto 20;
        end;
        ast_$release_aote(aote^);
      end;
    end;
    aote := ast_$aote_ptr_t(integer32(aote) + 16#C0);
  10:
  end;

  ml_$unlock(ml_$ast_lock);
  vtoc_$dismount(vol_index, force, local_status);

20:
  ast_$vol_info_count := ast_$vol_info_count - [vol_index];
  proc1_$inhibit_end;
  status := local_status;
end;
