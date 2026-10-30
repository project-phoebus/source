{ AST_$INVALIDATE - invalidate a run of an object's pages.

  Image addresses:
    sau2  0x00E0662E  AST_$INVALIDATE
    sau9  0x3C4078B2  AST_$INVALIDATE
    sau2  0x00E062FA  ast_$invalidate_with_wait (nested)
    sau9  0x3C407586  ast_$invalidate_with_wait (nested)
    sau2  0x00E064B0  ast_$invalidate_no_wait (nested)
    sau9  0x3C407734  ast_$invalidate_no_wait (nested)

  - Inhibited and under the AST lock, the object's AOTE is found (marked
    busy) or activated.  A run inside the object, its end clipped to the
    last page, is invalidated with the AOTE in transition.
  - With flags set the nested ast_$invalidate_with_wait does it, else
    ast_$invalidate_no_wait.  A remote object's pages are then
    invalidated at its node (REM_FILE_$INVALIDATE).

  Status stored:
    status_$ok: the pages were invalidated
    ast_$force_activate_segment's status: the object was not activated
    ast_$invalidate_with_wait's result: flags set, a page was wired
    rem_file_$invalidate's status: the remote call failed
}

procedure ast_$invalidate(in uid: uid_$t; start_page: linteger;
                          page_count: integer32; flags: boolean;
                          out status: status_$t);
label
  10;
var
  node_addr: ast_node_addr_t;
  scratch: integer32;                     { the nested with_wait's }
  location: ast_$loc_word_t;
  aote: ast_$aote_ptr_t;
  end_page: integer32;
  is_remote: boolean;

%include 'ast/invalidate_with_wait.pas';  { ast_$invalidate_with_wait }
%include 'ast/invalidate_no_wait.pas';    { ast_$invalidate_no_wait }

begin
  status.all := status_$ok;
  proc1_$inhibit_begin;
  ml_$lock(ml_$ast_lock);

  aote := ast_$lookup_aote_by_uid(uid);
  if aote = nil then begin
    location.all := 0;
    aote := ast_$force_activate_segment(uid, location, status, false);
    if aote = nil then begin
      ml_$unlock(ml_$ast_lock);
      goto 10;
    end;
  end
  else
    aote^.flags := aote^.flags + [6];

  is_remote := aote^.loc.remote;

  if (aote^.length <> 0)
     and then (rshft(aote^.length - 1, 10) >= start_page) then begin
    end_page := start_page + page_count - 1;
    if end_page > rshft(aote^.length - 1, 10) then
      end_page := rshft(aote^.length - 1, 10);
    aote^.flags := aote^.flags + [7];
    if flags then
      status := ast_$invalidate_with_wait(end_page)
    else
      ast_$invalidate_no_wait(end_page);
    aote^.flags := aote^.flags - [7];
    ec_$advance(ast_$ast_in_trans_ec);
  end;

  node_addr := ast_aote_addr_view_ptr_t(aote)^.node_addr;
  ml_$unlock(ml_$ast_lock);

  if is_remote and then (status.all = status_$ok) then
    rem_file_$invalidate(node_addr.net, uid, start_page, page_count,
                         flags, status);

10:
  proc1_$inhibit_end;
end;
