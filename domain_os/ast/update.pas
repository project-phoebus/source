{ AST_$UPDATE - the periodic write-back of dirty segments and attributes.

  Image addresses:
    sau2  0x00E016D0  AST_$UPDATE
    sau9  0x3C402A82  AST_$UPDATE

  - Nothing is done on a really diskless node.
  - Under the AST lock the AOTEs are visited from AST_$UPDATE_SCAN's
    on: an idle one marked for update has its dirty, unwired ASTEs
    written back and is then purified.
  - A pass stops after 32 segments or 75 AOTEs; at the table's end the
    volume buffers are flushed and the scan wrapped.

  Status stored: none.
}

procedure ast_$update;
label
  10;
var
  status: status_$t;
  aote_count: pinteger;
  aste_count: pinteger;
  aote: ast_$aote_view_ptr_t;
  aste: ast_$aste_ptr_t;
begin
  if network_$really_diskless then
    return;

  ml_$lock(ml_$ast_lock);
  aote_count := 0;
  aote := ast_$aote_view_ptr_t(ast_$update_scan);
  aste_count := 0;

  repeat
    if (12 in aote^.attrs.attr_set) and then not (7 in aote^.aote.flags)
       and then (aote^.ref_count = 0) then begin
      { the object's segments }
      aste := aote^.aote.aste_list;
      while aste <> nil do begin
        if not (15 in aste^.flags) and then (13 in aste^.flags) and then
           (aste^.wire_count = 0) and then
           (aste^.segment <= ast_$update_timestamp) then begin
          aste^.flags := aste^.flags + [15];
          ml_$unlock(ml_$ast_lock);
          ast_$update_aste(aste^, ast_pmaps[aste^.seg_index], false, status);
          ml_$lock(ml_$ast_lock);
          aste^.flags := aste^.flags - [15];
          ec_$advance(ast_$ast_in_trans_ec);
          if status.all <> status_$ok then
            exit;

          aste_count := aste_count + 1;
          if (aste_count >= 32) and then (aste^.segment <> 0) then begin
            ast_$update_timestamp := aste^.segment - 1;
            goto 10;
          end;
        end;
        aste := aste^.next;
      end;

      ast_$update_timestamp := 16#FFFF;
      if not (7 in aote^.aote.flags) then begin
        aote^.aote.flags := aote^.aote.flags + [7];
        ast_$purify_aote(aote^, false, status);
        aote^.aote.flags := aote^.aote.flags - [7];
        ec_$advance(ast_$ast_in_trans_ec);
      end;
      aote_count := aote_count + 1;
    end;

    aote := ast_$aote_view_ptr_t(integer32(aote) + 16#C0);
    if linteger(aote) >= linteger(ast_$aote_limit) then begin
      if not network_$really_diskless then begin
        ml_$unlock(ml_$ast_lock);
        dbuf_$update_vol(0, uid_$nil);
        ml_$lock(ml_$ast_lock);
      end;
      aote := ast_$aote_view_ptr_t(addr(aot[1]));
      exit;
    end;

  until (aote_count >= 75) or else (aste_count >= 32);

10:
  ast_$update_scan := ast_$aote_ptr_t(aote);
  ml_$unlock(ml_$ast_lock);
end;
