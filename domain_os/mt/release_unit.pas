{ mt_$release_unit - give up a tape unit: purge its queue, free its PBU
  resources, and shut the controller down after the last unit.

  Image addresses:
    sau3  0x00E6FF94  mt_$release_unit
    sau4  0x0F87CD0C  mt_$release_unit
    sau5  0x00E75AFC  mt_$release_unit
    sau6  0x7807C7BE  mt_$release_unit

  - When it was the last acquired unit, a failure to free the
    controller's region crashes the system; the other steps' statuses
    are ignored.

  Status stored: none.
}

procedure mt_$release_unit(unit: integer); internal;
var
  status: status_$t;
  u: integer;
begin
  u := unit;
  mt_$queue_request(u, mt_op_check, 0, 0, 0, status);
  with mt_$scb, units[u] do begin
    flags.bits := flags.bits - [mt_unit_pending];
    flags.bits := flags.bits + [mt_unit_purging];
    mt_purge_ucb(u);
    flags.bits := flags.bits - [mt_unit_purging];
    if mt_unit_mapped in flags.bits then
      pbu_$free(pbu_unit, iova_base, max_pages, status);
    if hdr_addr <> 0 then
      pbu_$delete_ppn(pbu_unit, hdr_addr, status);
    flags.bits := flags.bits - [mt_unit_mapped];
    n_acquired := n_acquired - 1;
    if n_acquired < 0 then
      n_acquired := 0
    else if n_acquired = 0 then begin
      if cfg_pages <> 0 then begin
        pbu_$free(pbu_unit, cfg_iova[1], cfg_pages, status);
        if status.all <> 0 then
          crash_system(status);
        cfg_pages := 0;
      end;
      mt_$shutdown;
    end;
    pbu_$release_int(pbu_unit, mt_release_mode, status);
    flags.bits := flags.bits - [mt_unit_acquired];
  end;
end;
