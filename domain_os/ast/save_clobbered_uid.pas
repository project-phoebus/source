{ AST_$SAVE_CLOBBERED_UID - remember a clobbered object and queue its
  trouble mark.

  Image addresses:
    sau2  0x00E07220  AST_$SAVE_CLOBBERED_UID
    sau7  0x3C407E7A  AST_$SAVE_CLOBBERED_UID
    sau9  0x3C40867A  AST_$SAVE_CLOBBERED_UID

  - The UID is kept in ast_$clobbered_uid, and AST_$SET_TROUBLE queued
    on DXM_'s unwired queue with a copy of it (duplicates checked); the
    queue's status is not read.

  Status stored: none.
}

procedure ast_$save_clobbered_uid(uid: uid_$t);
var
  status: status_$t;
begin
  ast_$clobbered_uid := uid;

  dxm_$add_callback(dxm_$unwired_q, addr(ast_$set_trouble),
                    addr(ast_$clobbered_uid), 8, true, status);
end;
