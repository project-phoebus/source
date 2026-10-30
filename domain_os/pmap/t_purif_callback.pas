{ PMAP_$T_PURIF_CALLBACK - the purifier timer's callback: age one list.

  Image addresses:
    sau2  0x00E143CC  PMAP_$T_PURIF_CALLBACK
    sau9  0x3C4166B2  PMAP_$T_PURIF_CALLBACK

  - Each call takes the next working set list, 5..16#45 in turn.
  - A list with pages not scanned for 458 ticks is purged or scanned
    under the PMAP lock, and PMAP_$PAGES_EC is advanced.

  Status stored: none.
}

procedure pmap_$t_purif_callback;
var
  now: integer32;
  quarter: linteger;
  limit: integer32;
begin
  if pmap_$current_slot = 16#45 then
    pmap_$current_slot := 5
  else
    pmap_$current_slot := pmap_$current_slot + 1;
  pmap_$t_pur_scans := pmap_$t_pur_scans + 1;

  now := time_$clockh;
  with mmap_$wsl[pmap_$current_slot] do begin
    if not (13 in flags) then begin
      quarter := rshft(mmap_$pageable_pages, 2);
      if quarter > 2048 then
        quarter := 2048;
      max_pages := mmap_$pageable_pages - quarter;
    end;

    if page_count <> 0 then begin
      limit := now - 458;
      if limit >= ws_timestamp then begin
        ml_$lock(ml_$pmap_lock);
        { never scanned and long unused: purged }
        if (ws_timestamp = 0) and then (limit > pri_timestamp) then
          mmap_$purge(pmap_$current_slot)
        else begin
          scan_pos := page_count;
          if (14 in flags) or else (owner > pmap_$ws_interval) or else
             ((pri_timestamp > ws_timestamp) and then
              (now - 38 > pri_timestamp)) then begin
            owner := 0;
            ws_timestamp := now;
            discard(mmap_$ws_scan(pmap_$current_slot, false, 16#3FFFFF,
                                  16#3FFFFF));
          end
          else
            { a scan that only ages the pages }
            discard(mmap_$ws_scan(pmap_$current_slot, true, 16#3FFFFF,
                                  16#3FFFFF));
        end;
        ml_$unlock(ml_$pmap_lock);
        ec_$advance(pmap_$pages_ec);
      end;
    end;
  end;
end;
