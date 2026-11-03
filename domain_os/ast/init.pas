{ AST_$INIT - size and build the AOTE and ASTE pools.

  Image addresses:
    sau2  0x00E2F000  AST_$INIT
    sau4  0x0F832400  AST_$INIT
    sau8  0x03C31C00  AST_$INIT
    sau9  0x3C434C00  AST_$INIT

  - Per 512-page unit of real memory: 80 ASTEs (plus 640) and 40 AOTEs
    (rounded to whole pages of AOTEs), each count clamped to its table's
    size (ast_$max_aotes AOTEs, ast_$max_astes ASTEs).
  - AST_$ADD_AOTES and AST_$ADD_ASTES build the pools; a failure of
    either crashes the system.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure ast_$init;
var
  status: status_$t;
  blocks: integer;
  pages: integer;
  aote_count: integer;
  aste_count: integer;
begin
  blocks := rshft(mmap_$real_pages + 16#1FF, 9);
  aste_count := blocks * 80 + 640;
  aote_count := blocks * 40;

  pages := (aote_count * 192 + 1023) div 1024;
  aote_count := (pages * 1024) div 192;
  if aote_count > ast_$max_aotes then
    aote_count := ast_$max_aotes;

  discard(ast_$add_aotes(aote_count, status));
  if status.all <> status_$ok then
    crash_system(status);

  if aste_count > ast_$max_astes then
    aste_count := ast_$max_astes;
  discard(ast_$add_astes(aste_count, status));
  if status.all <> status_$ok then
    crash_system(status);
end;
