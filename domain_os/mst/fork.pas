{ MST_$FORK - copy the current address space's segment tables into a new
  ASID, copying its anonymous areas.

  Image addresses:
    sau2  0x00E739F8  MST_$FORK
    sau4  0x0F880F9C  MST_$FORK
    sau8  0x03C7E278  MST_$FORK
    sau9  0x3C47B358  MST_$FORK

  - Under the ASID lock each parent MST word naming a page of MSTEs gets
    a fresh page for the child, and the entries are copied.
  - An anonymous object's area the parent owns is copied (AREA_$COPY,
    once per run of one handle); the child's entry gets the new handle.
  - With the large address space each page's segment map entries are
    copied too, made invalid for the child's MST_$TOUCH to fill.
  - The child's MST_$SEGS_MAPPED counts the entries copied.
  - With the layout chosen at boot or the region registers the child's
    first entry, the OS wired segment's, counted already, is counted
    once less and its segment map entry made valid again.
  - new_handle is not written before the first AREA_$COPY.

  Status stored:
    status_$ok: copied
    the table page's or AREA_$COPY's status: that failed
}

[section(proc2_create_pro, data$)]
procedure mst_$fork(asid: integer; pid: pinteger; flags: integer32;
                    out status: status_$t);
label
  fail;
var
  fork_flags: integer32;
  last_handle: area_$handle_t;
  handle: area_$handle_t;
  new_handle: integer32;
  parent_asid: integer;
  child_base: pinteger;
  page: integer;
  e: integer;
  st: status_$t;
  unused_20: integer32;                   { stand-in }
  parent_base: pinteger;
%if vm_regions %then
  seg: pinteger;
%endif
begin
  fork_flags := flags;
  parent_asid := proc1_$as_id;
  ml_$lock(ml_$mst_asid_lock);
  parent_base := mst_asid_base[parent_asid];
  child_base := mst_asid_base[asid];
  for page := 0 to rshft(mst_$seg_tn, 6) - 1 do
    if mst[parent_base + page] <> 0 then begin
      st := mst_$alloc_table_page(asid, lshft(page, 6),
                                  mst[child_base + page]);
      if st.all <> status_$ok then goto fail;
    end;

  last_handle := area_$handle_t(integer32(0));
  for page := 0 to rshft(mst_$seg_tn, 6) - 1 do
    if mst[parent_base + page] <> 0 then begin
%if vm_regions %then
      seg := lshft(page, 6);
      for e := 0 to 63 do begin
        smaps[seg + e + smap_asid_base[asid]] :=
          smaps[seg + e + smap_asid_base[parent_asid]];
%if region_mmu %then
        smaps[seg + e + smap_asid_base[asid]].bits :=
          smaps[seg + e + smap_asid_base[asid]].bits - [31];
%else
        smaps[seg + e + smap_asid_base[asid]].ctl.dt := mst_smap_invalid;
%endif
      end;
%endif
      for e := 0 to 63 do
        with mste_pages[mst[parent_base + page]][e]: src,
             mste_pages[mst[child_base + page]][e]: dst do begin
          dst := src;
          if src.uid.high <> 0 then begin
            handle := src.handle;
            if src.uid.high = anon_$uid.high then
              if (handle.generation =
                  areas[handle.area_id].generation) and then
                 (areas[handle.area_id].owner_asid = parent_asid) then begin
                if handle <> last_handle then begin
                  new_handle := area_$copy(handle, asid, pid,
                                           fork_flags, st);
                  if st.all <> status_$ok then begin
                  fail:
                    ml_$unlock(ml_$mst_asid_lock);
                    status := st;
                    return;
                  end;
                  last_handle := handle;
                end;
                dst.uid.low := new_handle;
                dst.flags.aste_idx := 0;
              end;
%if vm_regions %then
            mst_$segs_mapped[asid][seg div mst_region_segs] :=
              mst_$segs_mapped[asid][seg div mst_region_segs] + 1;
%endif
          end;
        end;
    end;
%if run_time_layout %then
  mst_$segs_mapped[asid][0] := mst_$segs_mapped[asid][0] - 1;
  smaps[smap_asid_base[asid]].ctl.dt := mst_smap_valid;
%elseif region_mmu %then
  mst_$segs_mapped[asid][0] := mst_$segs_mapped[asid][0] - 1;
  smaps[smap_asid_base[asid]].e.valid := true;
%endif
  ml_$unlock(ml_$mst_asid_lock);
  status.all := status_$ok;
end;

{ TODO(pascal) MST_$FORK: dpc gives a frame 16 bytes larger than the
  image's and lacks its strength-reduced element pointers, so the frame
  is not checked.  The locals follow the image's addressed slots, with
  the register-held ones and a stand-in in the holes. }
