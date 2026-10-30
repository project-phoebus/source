{ pmap_$write_page - write one dirty page to its backing store.

  Image addresses:
    sau2  0x00E12E5E  pmap_$write_page
    sau9  0x3C4151D0  pmap_$write_page

  Assume we're called with the PMAP lock held.

  - The write is done with the lock released.
  - An area page (flags2_7) goes to the area partner, a remote object's
    page to its node, a local page to its disk address.
  - An area page whose ASTE is not remote, an area page's refused write
    and a local page with no disk address crash the system.

  Status stored:
    status_$ok: the page was written ("disk write protected" counts)
    status_$ast_last_page_partially_written, its fail bit set: sync is
      set and an object's last page took more than one packet
    network_$write's status: the write was refused as a concurrency
      violation, "object not found" or "end of file"; an object's page
      is invalidated
    network_$write's or disk_$write's status, its fail bit set: any other
      failed write; the page stays dirty
}

procedure pmap_$write_page(vpn: linteger; var status: status_$t;
                           sync: boolean);
  internal;
var
  segment: pinteger;
  req: network_$page_request_t;
  node: uid_$t;
  dtm: time_$clock_t;
  dtv_low: pinteger;
  pkt_size: integer;
  volx: integer;
  max_shift: integer32;
  seg_offset: pinteger;
  is_area: boolean;
  remote: boolean;
  count: pinteger;
  aote: ast_$aote_ptr_t;
  area_id: pinteger;
  pn: linteger;
  off: linteger;
  max_size: pinteger;
  new_dtv_low: pinteger;
  daddr: linteger;
label
  10;
begin
  segment := mmap[vpn].segment;
  seg_offset := mmap[vpn].seg_offset;

  { the request }
  is_area := mmap[vpn].flags2_7;
  if is_area then begin
    aote := ast[segment].aote;
    area_id := area_$entry_ptr_t(aote)^.area_id;
    if not (11 in ast[segment].flags) then
      crash_system(status_$area_internal_error);
    remote := true;
    req.sub_type := chr(0);
    req.uid.high := anon_$uid.high;
    req.uid.low := areas[area_id].remote_volx;
    pn := seg_offset + lshft(ast[segment].segment, 5);
    req.page_num := pn;
    req.page_num := req.page_num + rshft(pn + 16#100, 8);
  end
  else begin
    aote := ast[segment].aote;
    remote := 11 in ast[segment].flags;
    volx := aote^.vol_index;
    req.uid := aote^.uid;
    req.page_num := lshft(ast[segment].segment, 5) + seg_offset;
    req.sub_type := aote^.sub_type;
  end;

  req.reserved_10 := chr(0);
  { the page in transit; with disk checksums on, a local page loses its
    translation }
  ast_pmaps[segment][seg_offset].flags :=
    ast_pmaps[segment][seg_offset].flags + [ast_$pmap_in_trans];
%if pmmu_page_maps %then
  if not remote and then disk_$do_chksum then begin
    ast_pmaps[segment][seg_offset].flags :=
      ast_pmaps[segment][seg_offset].flags - [ast_$pmap_resident];
    mmu_$purge;
  end;
%else
  if not remote and then disk_$do_chksum and then
     (ast_$pmap_resident in ast_pmaps[segment][seg_offset].flags) then begin
    ast_pmaps[segment][seg_offset].flags :=
      ast_pmaps[segment][seg_offset].flags - [ast_$pmap_resident];
    mmu_$remove(vpn);
  end;
%endif

  if netlog_$ok_to_log then
    netlog_$log_it(3, req.uid, rshft(req.page_num, 5), seg_offset, vpn,
                   0, 0, 0);
  ml_$unlock(ml_$pmap_lock);

  if remote then begin
    { where to, and in how many packets }
    count := 1;
    if is_area then begin
      req.reserved_0c := 0;
      node := area_$partner;
      pkt_size := area_$partner_pkt_size;
    end
    else begin
      req.reserved_0c := aote^.dtv.high;
      node := aote^.obj_loc_addr;
      pkt_size := lshft(1, (aote^.unknown_9d & 15) + 9);
      max_shift := (aote^.loc_flags & 15) + 9;
      max_size := lshft(1, max_shift);
      { an object's short last page goes in several 1024-byte packets }
      if max_size < 1024 then begin
        off := lshft(lshft(ast[segment].segment, 5) + seg_offset, 10);
        if off <= aote^.length then
          if off + 1024 - max_size >= aote^.length then begin
            count := (aote^.length - off + 1023) div 1024;
            if count = 0 then
              crash_system(status_$pmap_bad_assoc);
            pkt_size := 1024;
          end;
      end;
    end;

    network_$write(node, req, vpn, pkt_size, count, dtv_low, dtm, status);
    new_dtv_low := dtv_low;
    ml_$lock(ml_$pmap_lock);

    if status.all = status_$ok then begin
      if not is_area then begin
        aote^.dtv.high := req.reserved_0c;
        aote^.dtv.low := new_dtv_low;
        aote^.dtm := dtm;
        aote^.dta := dtm;
        if sync and then (count <> 1) then
          status.all := status_$ast_last_page_partially_written;
      end
      else begin
        mmap[vpn].disk_addr.all := 1;
        ast[segment].flags := ast[segment].flags + [13];
      end;
      proc1_$stats[proc1_$current].stat[4] :=
        proc1_$stats[proc1_$current].stat[4] + 1;
    end
    else if (status.all =
             status_$network_memory_parity_error_during_transmit) and then
            not is_area then begin
      ml_$unlock(ml_$pmap_lock);
      ast_$save_clobbered_uid(aote^.uid);
      ml_$lock(ml_$pmap_lock);
    end
    else begin
      { a refused write invalidates the page; any other failure leaves it
        to pmap_$write_complete }
      if status.all = status_$ast_write_concurrency_violation then
        network_$write_viol_cnt := network_$write_viol_cnt + 1
      else if (status.all <> file_$object_not_found) and then
              (status.all <> status_$ast_eof) then
        goto 10;
      ast_pmaps[segment][seg_offset].flags :=
        ast_pmaps[segment][seg_offset].flags - [ast_$pmap_in_trans];
      ec_$advance(ast_$pmap_in_trans_ec);
      if is_area then
        crash_system(status)
      else
        ast_$invalidate_page(ast[segment], ast_pmaps[segment][seg_offset],
                             vpn);
      return;
    end;
  end
  else begin
    { a local page }
    daddr := mmap[vpn].disk_addr.daddr;
    if daddr = 0 then
      crash_system(status_$pmap_bad_disk_address);
    disk_$write(volx, daddr, vpn, req, status);
    if status.all = status_$disk_write_protected then
      status.all := status_$ok;
    proc1_$stats[proc1_$current].stat[3] :=
      proc1_$stats[proc1_$current].stat[3] + 1;
    ml_$lock(ml_$pmap_lock);
  end;

10:
  pmap_$write_complete(vpn, status);
  if status.all = status_$ok then
    ec_$advance(ast_$pmap_in_trans_ec);
end;
