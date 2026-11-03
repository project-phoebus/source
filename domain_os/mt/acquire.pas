{ MT_$ACQUIRE - acquire a magnetic tape unit for the calling process.

  Image addresses:
    sau3  0x00E7017E  MT_$ACQUIRE
    sau4  0x0F87CEF6  MT_$ACQUIRE
    sau5  0x00E75CE8  MT_$ACQUIRE
    sau3  0x00E700A4  init_unit (nested)
    sau4  0x0F87CE1C  init_unit (nested)
    sau5  0x00E75C0C  init_unit (nested)

  - The first acquisition wires the driver's pages (the MT page and the
    MT_$SIO code); while the controller is not enabled it is set up,
    probed, reset and given its request block pool.
  - The unit is rewound and waited for; an offline unit, or one not at
    the load point, is acquired with a warning status.
  - A failure after the unit was taken releases it (mt_$release_unit).
    The result is audited when auditing is on.
  - init_unit (nested): a PBU_$GET_PTR failure crashes the system.
  - A header address other than 0 fails (hdr_addr stays 0); the
    controller setup's two stores into the pool's area (w_368, iova_36a)
    are cleared again by the pool's initialization.

  Status stored:
    status_$ok: the unit was acquired
    status_$mt_offline: acquired, but the unit is offline
    status_$mt_not_at_load_point: acquired, but not at the load point
    status_$mt_no_pna_board: the PBU is not present
    status_$mt_invalid_unit_number: unit is not 0, 1 or 4
    status_$mt_unit_in_use: PBU_$ACQUIRE_INT found the unit in use
    status_$mt_already_acquired: PBU_$ACQUIRE_INT found it acquired
    pbu_$acquire_int's status, its fail bit set: any other refusal
    status_$mt_config_page_in_use_fail: the configuration page could not
      be allocated
    status_$mt_not_connected: the controller does not answer the probe
    status_$mt_drive_hung: the reset did not complete
    status_$mt_invalid_buffer_length: max_length is not
      1..mt_max_length
    status_$mt_invalid_parameter: header is not 0
    pbu_$alloc's or pbu_$free's status, its fail bit set: an I/O map
      region could not be allocated, or the configuration page freed
    mt_$queue_request's, mt_$wait's or mt_$control's status: the setup
      request or the rewind failed
}

procedure mt_$acquire;
label
  7, 8, 9, 10;
var
  hdr: linteger;
  p: mt_$long_ptr_t;
  st: status_$t;
  st2: status_$t;
  info: mt_$wait_info_t;
  data: integer;
  audit_flags: pinteger;
  u: integer;
  count: integer;
  cfg_alloc: linteger;
  first_count: integer;
  i: integer;

  procedure init_unit;
  var
    st: status_$t;
    size: integer32;
  begin
    with mt_$scb, units[u] do begin
      flags.bits := flags.bits + [mt_unit_purging];
      mt_purge_ucb(u);
      flags.bits := flags.bits - [mt_unit_purging];
      n_acquired := n_acquired + 1;
      flags.bits := flags.bits + [mt_unit_acquired];
      flags.bits := flags.bits
                    - [mt_unit_flag_11, mt_unit_pending, mt_unit_batch];
      mode_bits := default_mode;
      if unit > 3 then
        mode_bits.bits := mode_bits.bits + [8]
      else
        mode_bits.drive := unit;
      hdr_addr := 0;
      l_26 := 0;
      dcte := pbu_$get_ptr(pbu_unit, pbu_ptr_dcte, size, st);
      if st.all <> 0 then
        crash_system(st);
    end;
  end;

%include 'mt/set_iomap.pas';             { mt_$set_iomap (nested) }

begin
  if not pbu_$mcb.present then begin
    status.all := status_$mt_no_pna_board;
    goto 10;
  end;
  if unit = 0 then
    u := 0
  else if (unit = 1) or else (unit = 4) then
    u := 1
  else begin
    status.all := status_$mt_invalid_unit_number;
    goto 10;
  end;
  with mt_$scb.units[u] do begin
    cfg_alloc := 0;
    ml_$lock(ml_$mt_lock);
    flags.bits := flags.bits - [mt_unit_pending];
    pbu_$acquire_int(pbu_unit, addr(mt_$int), nil, addr(pbu_mt_page),
                     16#7800, 1, 3, status);
    if status.all <> 0 then begin
      case status.all of
        status_$pbu_unit_in_use:
          status.all := status_$mt_unit_in_use;
        status_$pbu_unit_already_acquired:
          status.all := status_$mt_already_acquired;
        otherwise
          status.fail := true;
      end;
      ml_$unlock(ml_$mt_lock);
      goto 10;
    end;
    st.all := 0;
    init_unit;
    proc2_$set_cleanup(proc2_$cleanup_mt);

    if not (mt_scb_wired in mt_$scb.flags.bits) then begin
      mst_$wire_area(addr(mt_$page_start), addr(mt_$page_end), mt_wired,
                     mt_page_pages, mt_wired_count);
      first_count := mt_wired_count;
      mst_$wire_area(addr(mt_$proc_start), addr(mt_$proc_end),
                     mt_wired[mt_wired_count + 1],
                     mt_max_wired - mt_wired_count, count);
      mt_wired_count := mt_wired_count + count;
      mt_$scb.flags.bits := mt_$scb.flags.bits + [mt_scb_wired];
      if mt_scb_enabled in mt_$scb.flags.bits then
        for i := 1 to mt_$scb.cfg_pages do
          mt_$set_iomap(mt_wired[i], mt_$scb.cfg_iova[i]);
    end;

    if not (mt_scb_enabled in mt_$scb.flags.bits) then begin
      cfg_alloc := pbu_$alloc(pbu_unit, true, 1, 16#FC00, st2);
      if st2.all <> 0 then begin
        cfg_alloc := 0;
        st.all := status_$mt_config_page_in_use_fail;
        goto 9;
      end;
      mt_$set_iomap(mt_wired[1], 16#FC00);
      mt_$scb.cfg_iova[1] := pbu_$alloc(pbu_unit, false, first_count, 0, st);
      if st.all <> 0 then
        goto 8;
      mt_$scb.cfg_pages := first_count;
      for i := 2 to mt_$scb.cfg_pages do
        mt_$scb.cfg_iova[i] := mt_$scb.cfg_iova[i - 1] + 16#400;
      for i := 1 to mt_$scb.cfg_pages do
        mt_$set_iomap(mt_wired[i], mt_$scb.cfg_iova[i]);
      mt_$scb.w_368 := 16#100;
      mt_$putiova(mt_$get_iova(addr(mt_$scb)), mt_$scb.iova_36a);
      mt_$putiova(mt_$get_iova(addr(mt_$scb.ctl_word)), mt_$scb.ctl_iova);
      count := 0;
      if not testpage(mt_probe_kind, addr(pbu_mt_page.control), count) then
      begin
        st.all := status_$mt_not_connected;
        goto 9;
      end;
      mt_$scb.ctl_word := mt_ctl_word_reset;
      pbu_mt_page.reset := mt_ctl_reset;
      i := 0;
      while mt_$scb.ctl_word = mt_ctl_word_reset do begin
        i := i + 1;
        if i > mt_reset_tries then begin
          st.all := status_$mt_drive_hung;
          goto 9;
        end;
      end;
      pbu_$free(pbu_unit, cfg_alloc, 1, st);
      if st.all <> 0 then
        goto 8;
      cfg_alloc := 0;
      p := addr(mt_$scb.pool);
      repeat
        p^ := 0;
        p := mt_$long_ptr_t(integer32(p) + 4);
      until integer32(p) > integer32(addr(mt_$page_end)) - 7;
      p := addr(mt_$scb.pool);
      mt_$scb.free_q.head := mt_$pb_ptr_t(p);
      repeat
        p^ := integer32(p) + mt_$scb.pb_size;
        p := mt_$long_ptr_t(p^);
      until integer32(p)
            >= integer32(addr(mt_$page_end)) - 2 * mt_$scb.pb_size;
      mt_$scb.free_q.tail := univ_ptr(p);
      mt_$queue_request(u, mt_op_setup, 0, 0, 0, st);
      if st.all <> 0 then
        goto 9;
      mt_$wait(unit, mt_acquire_timeout, info, 1, count, st);
      if st.all <> 0 then
        goto 9;
      mt_$scb.flags.bits := mt_$scb.flags.bits + [mt_scb_enabled];
    end;

    if (max_length <= 0) or else (max_length > mt_max_length) then begin
      st.all := status_$mt_invalid_buffer_length;
      goto 9;
    end;
    max_pages := (max_length + 16#3FE) div 1024 + 1;
    iova_base := pbu_$alloc(pbu_unit, false, max_pages, 0, st);
    if st.all <> 0 then
      goto 8;
    flags.bits := flags.bits + [mt_unit_mapped];
    mt_$control(unit, mt_control_1, st);
    if st.all <> 0 then
      goto 9;
    mt_$wait(unit, mt_acquire_timeout, info, 1, count, st);
    if st.all <> 0 then
      goto 9;
    if not (mt_status_online in info.tape_status) then
      st.all := status_$mt_offline
    else if not (mt_status_load_point in info.tape_status) then
      st.all := status_$mt_not_at_load_point;
    hdr := header;
    if hdr <> 0 then begin
      st.all := status_$mt_invalid_parameter;
      if hdr <> 0 then
        goto 9;
      hdr_pa.ppn := pbu_$save_ppn(pbu_unit, hdr, st);
      if st.all <> 0 then
        goto 8;
      hdr_addr := hdr;
    end;
    ml_$unlock(ml_$mt_lock);
    goto 7;
8:
    st.fail := true;
9:
    if cfg_alloc <> 0 then
      pbu_$free(pbu_unit, cfg_alloc, 1, st2);
    ml_$unlock(ml_$mt_lock);
    mt_$release_unit(unit);
7:
    status := st;
  end;
10:
  if audit_$enabled then begin
    if status.all <> 0 then
      audit_flags := 1
    else
      audit_flags := 0;
    data := unit;
    audit_$log_event(audit_$acquire_mt_eu, audit_flags, status, data, 2);
  end;
end;
