{ AST_$FREE_PAGES - drop a run of pages from a segment.

  Image addresses:
    sau2  0x00E0400C  AST_$FREE_PAGES
    sau9  0x3C405338  AST_$FREE_PAGES

  - The PMAP lock is held throughout, except around BAT_$FREE.
  - Installed pages are unmapped and freed 32 at a time; their disk
    blocks go back to the volume 32 at a time when vol_idx is not 0.
  - A BAT_$FREE failure crashes the system.

  Status stored: none.
}

procedure ast_$free_pages(var aste: ast_$aste_t; start_page: pinteger;
                          end_page: pinteger; vol_idx: integer);
  options(val_param);
label
  10;
var
  bat_blocks: array[1..32] of linteger;
  installed_pages: array[1..32] of integer32;
  status: status_$t;
  installed_count: pinteger;
  page: pinteger;
  disk_addr: linteger;
  bat_count: pinteger;

%include 'ast/flush_installed_pages.pas';   { ast_$flush_installed_pages
                                               (nested) }

begin
  ml_$lock(ml_$pmap_lock);
  bat_count := 0;
  installed_count := 0;

  for page := start_page to end_page do
    with ast_pmaps[aste.seg_index, page] do begin
      { a page in transition: wait it out, the gathered pages flushed first }
      while ast_$pmap_in_trans in flags do begin
        if installed_count <> 0 then
          ast_$flush_installed_pages;
        ast_$wait_for_page_transition;
      end;

      { an installed page's disk address is in its MMAP entry; a page not
        installed has its own, or none }
      if ast_$pmap_installed in flags then begin
        disk_addr := mmap[vpn].disk_addr.daddr;
        installed_count := installed_count + 1;
        installed_pages[installed_count] := vpn;
        if installed_count = 32 then
          ast_$flush_installed_pages;
      end
      else begin
        disk_addr := dentry.daddr;
        if disk_addr = 0 then
          goto 10;
      end;

      aste.flags := aste.flags + [13];      { the segment is modified }

    10:
      all := 0;

      if (disk_addr <> 0) and then (vol_idx <> 0) then begin
        bat_count := bat_count + 1;
        bat_blocks[bat_count] := disk_addr;
        { a full batch is freed without the PMAP lock }
        if bat_count = 32 then begin
          if installed_count <> 0 then
            ast_$flush_installed_pages;
          ml_$unlock(ml_$pmap_lock);
          bat_$free(bat_blocks, bat_count, vol_idx, 1, status);
          if status.all <> status_$ok then
            crash_system(status);
          ml_$lock(ml_$pmap_lock);
          bat_count := 0;
        end;
      end;
    end;

  { the partial batches }
  if installed_count <> 0 then
    ast_$flush_installed_pages;
  ml_$unlock(ml_$pmap_lock);

  if bat_count <> 0 then begin
    bat_$free(bat_blocks, bat_count, vol_idx, 1, status);
    if status.all <> status_$ok then
      crash_system(status);
  end;
end;
