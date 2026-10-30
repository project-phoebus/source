{ ast/ast_net.ins.pas - AST_$FETCH_PMAP_PAGE, the AST_ heading that
  needs NETWORK_'s request record.

  Its request is network/network.ins.pas's network_$page_request_t,
  which half of ast/ast.ins.pas's includers do not include (the others
  after it).  So it is an insert file of its own (ast/ast_acl.ins.pas's
  form).

  Include base, uid, ast and network before it: area/area.pas does.
  ast/ast.pas defines the routine (ast/fetch_pmap_page.pas) and does not
  include this file.
}

{ AST_$FETCH_PMAP_PAGE - read one page of a remote object into a buffer. }
procedure ast_$fetch_pmap_page(var req: network_$page_request_t;
                               out page: univ ast_$page_t;
                               pkt_size: integer; status: status_$t);
  options(extern, val_param);
