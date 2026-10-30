{ ast_$update_aste - write a dirty segment's file map back.

  Image addresses:
    sau2  0x00E01566  ast_$update_aste (module-local)
    sau9  0x3C40295E  ast_$update_aste (module-local)
    sau2  0x00E01502  ast_$update_aste_log (nested)
    sau9  0x3C4028FE  ast_$update_aste_log (nested)

  - A dirty local segment's 32 page-map entries are turned into their
    on-disk form under the PMAP lock and written with FM_$WRITE, with
    the caller's write-now flag.
  - ast_$update_aste_log, nested, writes a NETLOG record.

  Status stored:
    status_$ok: the map was written, or nothing was to be written (also
      when the disk is write protected)
    fm_$write's status, with the fail bit: the write failed
}

procedure ast_$update_aste(var aste: ast_$aste_t; var segmap: ast_$pmap_t;
                           write_now: boolean; out status_ret: status_$t);
  internal;
var
  disk: ast_$disk_image_t;
  aote: ast_$aote_view_ptr_t;
  i: integer;

  procedure ast_$update_aste_log;
  var
    marked: integer;
    i: integer;
  begin
    marked := 0;
    for i := 0 to 31 do
      if disk.u[i] >= 16#80000000 then
        marked := marked + 1;

    netlog_$log_it(12, aste.aote^.uid, aste.segment, ord(aste.page_count),
                   marked, 0, 0, 0);
  end;

begin
  if not (13 in aste.flags) or else (11 in aste.flags) then begin
    status_ret.all := status_$ok;
    return;
  end;
  aote := ast_$aote_view_ptr_t(aste.aote);

  aste.flags := aste.flags - [13];
  ml_$lock(ml_$pmap_lock);

  { the on-disk form of the 32 entries }
  for i := 0 to 31 do
    if not (ast_$pmap_installed in segmap[i].flags) then begin
      disk.fm.blocks[i] := segmap[i].dentry.daddr;
%if pmmu_page_maps %then
      if 15 in segmap[i].hi_flags then
%else
      if 6 in segmap[i].flags then
%endif
        disk.fm.blocks[i] := disk.fm.blocks[i] ! 16#80000000;
    end
    else begin
      disk.fm.blocks[i] := mmap[segmap[i].vpn].disk_addr.daddr;
      { the ASTE-dirty bit of the address word, a member of its high
        word }
%if large_vm %then
      if 5 in mmap[segmap[i].vpn].disk_addr.hi_set then
%else
      if 6 in mmap[segmap[i].vpn].disk_addr.hi_set then
%endif
        disk.fm.blocks[i] := disk.fm.blocks[i] ! 16#80000000;
    end;

  ml_$unlock(ml_$pmap_lock);
  if netlog_$ok_to_log then
    ast_$update_aste_log;

  fm_$write(aote^.obj_loc.fm, fm_$block_addr_t(aste.fm_block), aste.segment,
            disk.fm, write_now, status_ret);

  if status_ret.all <> status_$ok then
    if status_ret.all = status_$disk_write_protected then
      status_ret.all := status_$ok
    else begin
      status_ret.fail := true;
      aste.flags := aste.flags + [13];
    end;
end;
