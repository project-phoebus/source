{ pmap/pmap_flush.ins.pas - PMAP_$FLUSH's heading and its flags type, for
  the Domain Pascal tree.

  A separate insert beside pmap/pmap.ins.pas because the heading takes
  AST_'s records (ast/ast.ins.pas ast_$aste_t, ast_$pmap_t), and two of
  pmap.ins.pas's includers, disk/disk_vol.pas and proc1/proc1.pas, do not
  include ast/ast.ins.pas.  Its includers, pmap/pmap.pas (which defines
  the routine) and ast/ast.pas (AST_$DEACTIVATE_SEGMENT calls it),
  include base/base.ins.pas and ast/ast.ins.pas before it.
}

type
  { PMAP_$FLUSH's flags: 0 invalidates the pages, 1 drops modified pages
    unwritten, 2 writes remote pages asynchronously.  The members' names
    are not known. }
  pmap_$flush_flags_t = set of 0..15;

{ PMAP_$FLUSH (pmap/flush.pas): the result is the number of pages
  written. }
function pmap_$flush(var aste: ast_$aste_t; var segmap: ast_$pmap_t;
                     start_page: integer; count: integer;
                     flags: pmap_$flush_flags_t;
                     out status: status_$t): integer;
  options(extern, val_param);
