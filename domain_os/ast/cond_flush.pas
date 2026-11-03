{ AST_$COND_FLUSH - deactivate an object whose DTV has changed.

  Image addresses:
    sau2  0x00E05B9C  AST_$COND_FLUSH
    sau4  0x0F805F3A  AST_$COND_FLUSH
    sau9  0x3C406E32  AST_$COND_FLUSH

  - With process switching inhibited and under the AST lock, an active
    object whose DTV differs from the caller's clock is deactivated
    (purged, waited for) and its AOTE released.

  Status stored:
    status_$ok: the object was deactivated, or needed not be
    ast_$process_aote's status: the deactivation failed
}

procedure ast_$cond_flush(uid: uid_$t; in dtm: time_$clock_t;
                          out status: status_$t);
var
  local_status: status_$t;
  aote: ast_$aote_ptr_t;
begin
  local_status.all := status_$ok;
  proc1_$inhibit_begin;
  ml_$lock(ml_$ast_lock);

  aote := ast_$lookup_aote_by_uid(uid);
  if aote <> nil then
    if (aote^.dtv.high <> dtm.high) or else
       (aote^.dtv.low <> dtm.low) then begin
      ast_$process_aote(aote^, true, false, true, local_status);
      if local_status.all = status_$ok then
        ast_$release_aote(aote^);
    end;

  ml_$unlock(ml_$ast_lock);
  proc1_$inhibit_end;
  status := local_status;
end;
