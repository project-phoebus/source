{ MST_$TOUCH - fault in the page of a virtual address.

  Image addresses:
    sau2  0x00E0DD40  MST_$TOUCH
    sau4  0x0F80E384  MST_$TOUCH
    sau6  0x7800E4AC  MST_$TOUCH
    sau7  0x3C40F848  MST_$TOUCH
    sau8  0x03C0ED44  MST_$TOUCH
    sau9  0x3C40FE10  MST_$TOUCH

  - The address's MST slot gives its MSTE.  The page comes in by
    AREA_$TOUCH (an anonymous segment), MMU_$VTOP and MMAP_$WIRE (a
    wired request), PEB_$TOUCH (the OS wired segment), or the AST.
  - A guarded entry faults once (its modified bit cleared).
  - With the large VM layout the pages are not installed: the address
    space's segment map entry is pointed at the segment's page map (and
    threaded on it), and the protection is that entry's; the OS wired
    segment and the special segments fault as illegal.
  - The OS-wired arm returns the MST slot; the anonymous arm releases a
    PMAP lock it did not take; the wired arm does not test MMU_$VTOP's
    status.

  Status stored:
    status_$ok: the page is in
    status_$reference_to_illegal_address: no MST slot or MSTE
    status_$reference_to_out_of_bounds_address: past the object's end
    status_$mst_object_not_found: the file is gone
    status_$mst_guard_fault: a guarded entry (the page returned too)
    the callee's status: the route's call failed
}

function mst_$touch(virtual_addr: integer32; out status_ret: status_$t;
                    wire_flag: integer): integer32;
label
  normal, illegal, have_aste, activate, mmu_fail, fail, zero_result,
  install, done;
var
  ppn_list: ast_$ppn_list_t;
  segno: linteger;
  aste: ast_$aste_ptr_t;
  aote: ast_$aote_ptr_t;
  seg: pinteger;
  seg_index: pinteger;
  page: pinteger;
  diff: pinteger;
  asid: pinteger;
  table_page: pinteger;
  ast_idx: pinteger;
  ast_flags: pinteger;
  count: pinteger;
%if large_vm %then
  smap: ^mst_smap_t;
%endif
begin
  segno := rshft(virtual_addr, 15);
  if segno >= mst_$seg_mem_top then goto illegal;
  page := rshft(virtual_addr, 10) & 16#1F;
  seg := segno;
  if seg < mst_$private_a_size then begin
    seg_index := seg;
    asid := proc1_$as_id;
  end
  else begin
    diff := seg - mst_$seg_private_b;
    if diff < mst_private_b_count then begin
      seg_index := diff + mst_$private_a_size;
      asid := proc1_$as_id;
    end
    else begin
      diff := seg - mst_$seg_global_a;
      if diff < mst_$global_a_size then
        seg_index := diff
      else begin
        if seg < mst_$seg_global_b then goto illegal;
        seg_index := seg - mst_$seg_global_b
                     + mst_$global_a_size;
      end;
      asid := 0;
    end;
  end;

  table_page := mst[(seg_index div 64)
                    + mst_asid_base[asid]];
  if table_page = 0 then goto illegal;

  with mste_pages[table_page][seg_index & 16#3F] do begin
    if netlog_$ok_to_log then
      netlog_$log_it(mst_touch_netlog_kind, uid, area_id, page,
                     page_info.n_pages_m1 + 1, asid,
                     rshft(virtual_addr, 16),
                     virtual_addr);

    if first_byte <> 0 then goto normal;
    if uid.high = 0 then goto illegal;

    if uid.high = anon_$uid.high then begin
      if asid = 0 then goto illegal;
      proc1_$inhibit_begin;
      area_$touch(handle, area_id, page, seg_index, ppn_list,
                  status_ret);
      if status_ret.all <> status_$ok then goto mmu_fail;
%if not large_vm %then
      count := 1;
%endif
      goto install;
    end;

    if wire_flag <> 0 then begin
      ml_$lock(ml_$pmap_lock);
      ppn_list[1] := mmu_$vtop(virtual_addr, status_ret);
      if status_ret.all = status_$ok then
        mmap_$wire(ppn_list[1]);
      mst_$touch := ppn_list[1];
      ml_$unlock(ml_$pmap_lock);
      goto done;
    end;

%if large_vm %then
    { the kernel's wired pages and the special segments are never
      faulted in }
    if uid = os_wired_$uid then goto illegal;
    if uid.high <> special_seg_$uid.high then goto normal;
%else
    if uid <> os_wired_$uid then goto normal;
    if not peb_$info.wcs_loaded then goto illegal;
    if not peb_$touch(virtual_addr) then goto illegal;
    status_ret.all := status_$ok;
    mst_$touch := seg_index;
    goto done;
%endif

  illegal:
    status_ret.all := status_$reference_to_illegal_address;
    goto zero_result;

  normal:
    proc1_$inhibit_begin;
    ml_$lock(ml_$ast_lock);
    ast_idx := flags.aste_idx;
    if ast_idx = 0 then goto activate;
    aste := addr(ast[ast_idx]);
    if 15 in aste^.flags then goto activate;
    if aste^.segment <> area_id then goto activate;
    if 12 in aste^.flags then goto activate;
    if aste^.aote = nil then goto activate;
    aote := aste^.aote;
    if 7 in aote^.flags then goto activate;
    if aote^.uid <> uid then goto activate;
    aste^.wire_count := aste^.wire_count + 1;
    goto have_aste;

  activate:
    aste := ast_$mste_activate_and_wire(as_ast,
                                        status_ret);
    if aste = nil then begin
      ml_$unlock(ml_$ast_lock);
      goto fail;
    end;
    flags.aste_idx := aste^.seg_index;

  have_aste:
    ml_$unlock(ml_$ast_lock);
    ml_$lock(ml_$pmap_lock);
    ast_flags := 0;
    if asid = 0 then ast_flags := mst_touch_ast_global;
%if large_vm %then
    { the segment map entry: made to point at the page map if it does
      not, the entry threaded on the page map }
    smap := addr(smaps[seg_index + smap_asid_base[asid]]);
%if region_mmu %then
    if not smap^.e.valid then begin
      smap^.e.pmap_pa := aste^.pmap_pa;
      smap^.bits := smap^.bits + [31];
      bst[seg_index + bst_asid_base[asid]] :=
        mst_$pmap_link_t(aste^.pmap_link);
      aste^.pmap_link.asid := asid;
      aste^.pmap_link.seg := seg_index;
    end;
    { the protection: the entry's copy-on-write and writable bits }
    if (15 in flags.bits) and then smap^.b.copy_on_write then
      ast_flags := ast_flags ! mst_touch_ast_cow;
    if not smap^.b.writable then
      ast_flags := ast_flags ! mst_touch_ast_read_only;
%else
    if smap^.ctl.dt = mst_smap_invalid then begin
      smap^.table := (smap^.table & 15) + aste^.pmap_pa;
      smap^.lim.limit := 31;
      if asid = 0 then smap^.flags := smap^.flags + [9];
%if smap_shared_global_68851 %then
      { the bit set for a global segment is cleared at once on the
        MC68030; the MC68851 keeps it }
      if m68030 then begin
        smap^.flags := smap^.flags - [9];
        smap^.flags := smap^.flags + [10..15];
      end;
%elseif not smap_shared_global %then
      { the bit set for a global segment is cleared at once }
      smap^.flags := smap^.flags - [9];
      smap^.flags := smap^.flags + [10..15];
%endif
      smap^.ctl.dt := mst_smap_valid;
      bst[seg_index + bst_asid_base[asid]] :=
        mst_$pmap_link_t(aste^.pmap_link);
      aste^.pmap_link.asid := asid;
      aste^.pmap_link.seg := seg_index;
    end;
    { the protection: the entry's write protect and its writable bit }
    if (15 in flags.bits) and then not (2 in smap^.flags) then
      ast_flags := ast_flags ! mst_touch_ast_cow;
    if not (0 in smap^.table_bits) then
      ast_flags := ast_flags ! mst_touch_ast_read_only;
%endif
%else
    if (15 in flags.bits) and then flags.copy_on_write then
      ast_flags := ast_flags ! mst_touch_ast_cow;
    if not flags.writable then
      ast_flags := ast_flags ! mst_touch_ast_read_only;
%endif
    count := ast_$touch(aste^, node_$me, page,
                        page_info.n_pages_m1 + 1, ppn_list,
                        status_ret, ast_flags);
    aste^.wire_count := aste^.wire_count - 1;
    if count <> 0 then goto install;

  mmu_fail:
    ml_$unlock(ml_$pmap_lock);
  fail:
    proc1_$inhibit_end;
    if status_ret.all = status_$ast_eof then
      status_ret.all := status_$reference_to_out_of_bounds_address
    else if status_ret.all = file_$object_not_found then
      status_ret.all := status_$mst_object_not_found;
  zero_result:
    mst_$touch := 0;
    goto done;

  install:
%if not large_vm %then
    mmu_$install_list(count, ppn_list, virtual_addr, asid,
                      ord(flags.prot));
%endif
    if wire_flag <> 0 then
      mmap_$wire(ppn_list[1]);
    ml_$unlock(ml_$pmap_lock);
    proc1_$inhibit_end;
    if 14 in flags.bits then begin
      flags.bits := flags.bits - [14];
      status_ret.all := status_$mst_guard_fault;
    end;
    mst_$touch := ppn_list[1];
  end;
done:
end;
