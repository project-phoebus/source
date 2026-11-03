{ area_$resize - set an area's virtual and committed sizes.

  Image addresses:
    sau2  0x00E087BA  area_$remote_sync (nested)
    sau4  0x0F808B3C  area_$remote_sync (nested)
    sau2  0x00E08816  area_$resize (module-local)
    sau4  0x0F808B98  area_$resize (module-local)
    sau8  0x03C08D16  area_$remote_sync (nested)
    sau8  0x03C08D72  area_$resize (module-local)
    sau9  0x3C409E32  area_$remote_sync (nested)
    sau9  0x3C409E8E  area_$resize (module-local)

  - The virtual size is rounded up to 32 KB, the committed size to 1 KB.
  - A shrink frees the pages from the new size on (area_$free_segments)
    and gives a local area's surplus blocks back (BAT_$CANCEL); a remote
    one tells the partner (the nested area_$remote_sync, when is_grow).
  - A growth tells a remote partner first and allocates the overflow
    tables the new slot cells need; a larger commit is reserved with
    BAT_$RESERVE for a local area.
  - Failures of the frees crash the system.
  - With the large VM layout, under the PMAP lock, a shrink takes each
    dropped segment's thread apart, making its MST-mapped entries'
    segment map entries invalid, and flushes the translations after the
    frees; a growth sets the new segments' BST entries to none.
  - A failed table allocation's roll-back takes its size from the new
    virtual size, and its status is overwritten.

  Status stored:
    status_$ok: the sizes were set
    status_$area_not_active: the entry is not active
    status_$area_bad_reserve: a commit above the virtual size
    status_$area_no_free_resources: no overflow table could be had
    rem_file_$grow_area's or bat_$reserve's status: those failed
}

procedure area_$resize(area_id: integer; var entry: area_$entry_t;
                       virt_size: linteger; commit_size: linteger;
                       is_grow: integer; out status: status_$t);
var
  old_pages: linteger;
  new_pages: linteger;
  old_virt: linteger;
  old_commit: linteger;
  blocks: linteger;
  partner: linteger;
  partner_commit: linteger;
  old_segs: integer;
  new_segs: integer;
  s: integer;
%if large_vm %then
  link: mst_$pmap_link_t;
  next_link: mst_$pmap_link_t;
  seg: pinteger;
%else
  bste_scratch: integer;
  seg_scratch: integer;
%endif
  old_cell: integer;
  new_cell: integer;
  first_tbl: integer;
  last_tbl: integer;
  t: integer;
  tbl: area_$seg_table_ptr_t;
  next: area_$seg_table_ptr_t;
  prev: area_$seg_table_ptr_t;

  { area_$remote_sync - tell the diskless partner the area's new size.

    Image addresses:
      sau2  0x00E087BA  area_$remote_sync (nested)
      sau4  0x0F808B3C  area_$remote_sync (nested)
      sau8  0x03C08D16  area_$remote_sync (nested)
      sau9  0x3C409E32  area_$remote_sync (nested)

    - The partner's size is the virtual size plus one 1 KB block per
      started 256 KB; its commit that less the virtual size plus the
      committed size (REM_FILE_$GROW_AREA).

    Status stored (in the parent's status):
      rem_file_$grow_area's status: in either case
  }

  procedure area_$remote_sync;
  var
    size: linteger;
    commit: linteger;
  begin
    size := ((virt_size - 1) div 16#40000 + 1) * 1024 + virt_size;
    commit := size - virt_size + commit_size;

    rem_file_$grow_area(area_$partner, entry.remote_volx, size, commit,
                        status);
  end;

begin
  if not (area_$f_active in entry.flags) then begin
    status.all := status_$area_not_active;
    return;
  end;

  { round the sizes in their slots }
  virt_size := (virt_size + 16#7FFF) & (-16#8000);
  commit_size := (commit_size + 16#3FF) & (-16#400);
  if commit_size > virt_size then begin
    status.all := status_$area_bad_reserve;
    return;
  end;

  status.all := status_$ok;
  old_pages := rshft(entry.virt_size, 10);
  new_pages := rshft(virt_size, 10);
  old_virt := entry.virt_size;
  old_commit := entry.commit_size;

  if virt_size < old_virt then begin
    { ---- shrink ---- }

%if large_vm %then
    { each dropped segment's thread, taken apart }
%else
    { the loop stores and nothing reads }
%endif
    old_segs := rshft(old_pages + 32 - 1, 5);
    new_segs := rshft(new_pages + 32 - 1, 5);
    if (old_segs <> new_segs) and then (entry.first_bste <> -1) then begin
      ml_$lock(ml_$pmap_lock);
      for s := new_segs to old_segs - 1 do begin
%if large_vm %then
        link.asid := entry.first_bste;
        if area_$f_reversed in entry.flags then
          link.seg := entry.first_seg_index - s
        else
          link.seg := s + entry.first_seg_index;
        while link.asid <> -1 do begin
          if mst[rshft(link.seg, 6) + mst_asid_base[link.asid]] <> 0 then
%if region_mmu %then
            smaps[smap_asid_base[link.asid] + link.seg].e.valid := false;
%else
            smaps[smap_asid_base[link.asid] + link.seg].ctl.dt :=
              mst_smap_invalid;
%endif
          next_link := bst[bst_asid_base[link.asid] + link.seg];
          bst[bst_asid_base[link.asid] + link.seg].asid := -1;
          link := next_link;
        end;
%else
        bste_scratch := entry.first_bste;
        if area_$f_reversed in entry.flags then
          seg_scratch := entry.first_seg_index - s
        else
          seg_scratch := s + entry.first_seg_index;
%endif
      end;
      ml_$unlock(ml_$pmap_lock);
    end;

    area_$free_segments(area_id, new_pages, old_pages - 1, true, status);
    if status.all <> status_$ok then
      crash_system(status);
%if large_vm %then
    mmu_$purge;
%endif

    if entry.remote_volx = 0 then begin
      { a local area gives the surplus back }
      if old_commit > virt_size then begin
        blocks := (old_commit - virt_size) div 1024;
        if lshft(blocks, 10) > old_commit then
          crash_system(status_$area_internal_error);
        bat_$cancel(entry.volx, blocks, status);
        if status.all <> status_$ok then
          crash_system(status);
        entry.commit_size := virt_size;
      end;
    end
    else begin
      { a remote one tells its partner }
      if is_grow <> 0 then begin
        area_$remote_sync;
        if status.all <> status_$ok then
          return;
      end;
      if virt_size < old_commit then
        entry.commit_size := virt_size;
    end;
  end
  else begin
    if virt_size > old_virt then begin
      { ---- grow ---- }

      if (is_grow <> 0) and then (entry.remote_volx <> 0) then begin
        area_$remote_sync;
        if status.all <> status_$ok then
          return;
      end;

      old_cell := rshft(max(old_pages - 1, 0), 8);
      new_cell := (new_pages - 1) div 256;
      if new_cell >= 2 then begin
        first_tbl := 0;
        if old_cell >= 2 then
          first_tbl := rshft(old_cell - 2, 8) + 1;
        last_tbl := rshft(new_cell - 2, 8);

        { the overflow tables }
        for t := first_tbl to last_tbl do
          if area_$alloc_seg_table(entry.owner_asid, area_id, t) = nil then
          begin
            { free this area's tables from the first new one on }
            tbl := area_$seg_table_list[entry.owner_asid];
            prev := nil;
            while tbl <> nil do begin
              next := tbl^.next;
              if (tbl^.area_id = area_id) and then
                 (tbl^.table_index >= first_tbl) then
                area_$free_seg_table(tbl, prev, entry.owner_asid)
              else
                prev := tbl;
              tbl := next;
            end;

            { the roll-back for a remote partner: its size from the new
              virtual size }
            if (is_grow <> 0) and then (entry.remote_volx <> 0) then begin
              partner := ((virt_size - 1) div 16#40000 + 1) * 1024 +
                         virt_size;
              partner_commit := old_commit + partner - old_virt;
              rem_file_$grow_area(area_$partner, entry.remote_volx,
                                  partner, partner_commit, status);
            end;

            status.all := status_$area_no_free_resources;
            return;
          end;
      end;

      { the new inline cells must be empty }
      if old_pages = 0 then
        old_cell := 0
      else
        old_cell := old_cell + 1;
      if old_cell < 2 then begin
        if new_cell > 1 then
          new_cell := 1;
        for s := old_cell to new_cell do
          if integer32(entry.seg_bitmap[s]) <> 0 then
            crash_system(status_$area_internal_error);
      end;
%if large_vm %then

      { the new segments' BST entries: none }
      if entry.first_bste <> -1 then begin
        old_segs := rshft(old_pages + 32 - 1, 5);
        new_segs := rshft(new_pages + 32 - 1, 5);
        if old_segs <> new_segs then begin
          ml_$lock(ml_$pmap_lock);
          if area_$f_reversed in entry.flags then begin
            seg := entry.first_seg_index - old_segs;
            for s := old_segs to new_segs - 1 do begin
              bst[seg + bst_asid_base[entry.first_bste]].asid := -1;
              seg := seg - 1;
            end;
          end
          else begin
            seg := old_segs + entry.first_seg_index;
            for s := old_segs to new_segs - 1 do begin
              bst[seg + bst_asid_base[entry.first_bste]].asid := -1;
              seg := seg + 1;
            end;
          end;
          ml_$unlock(ml_$pmap_lock);
        end;
      end;
%endif
    end;

    { a larger commit }
    if old_commit < commit_size then begin
      if entry.remote_volx = 0 then begin
        bat_$reserve(entry.volx, (commit_size - old_commit) div 1024,
                     status);
        if status.all <> status_$ok then
          return;
      end;
      entry.commit_size := commit_size;
    end;
  end;

  entry.virt_size := virt_size;
end;
