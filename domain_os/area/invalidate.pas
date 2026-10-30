{ AREA_$INVALIDATE - discard a run of pages of an area.

  Image addresses:
    sau2  0x00E08DD0  AREA_$INVALIDATE
    sau9  0x3C40A5C2  AREA_$INVALIDATE

  - Nothing is done for a count of 0, an area never touched or one of
    size 0.  Otherwise, checked as AREA_$GROW and marked in transition,
    the pages are freed with area_$free_segments, the lock released.
  - A reversed area (segment n is group -n - 1) frees a partial first
    group, the whole groups below it, then the rest.
  - The reversed area's first range starts from page_offset as it was
    before the clamp.

  Status stored:
    status_$ok: the pages were freed, or none were to be
    status_$area_not_active: an id outside 1..AREA_$N_AREAS, an entry
      not active or of another generation
    status_$area_not_owner: a local area of another address space
    area_$free_segments's status: a call failed
}

procedure area_$invalidate(handle: area_$handle_t; seg_idx: pinteger;
                           page_offset: pinteger; count: linteger;
                           unused_flag: boolean; out status: status_$t);
label
  10;
var
  status_l: status_$t;
  last_page: integer32;
  first_page: linteger;
  entry: area_$entry_ptr_t;
  max_page: linteger;
  remaining: linteger;
  group: pinteger;
  start: linteger;
  last: integer32;
  group_last: integer32;
begin
  if (handle.area_id = 0) or else (handle.area_id > area_$n_areas) then
  begin
    status.all := status_$area_not_active;
    return;
  end;

  status_l.all := status_$ok;
  entry := addr(areas[handle.area_id]);

  { nothing to discard }
  if (count <> 0) and then (area_$f_touched in entry^.flags) and then
     (entry^.virt_size <> 0) then begin
    ml_$lock(ml_$area_lock);
    while area_$f_in_trans in entry^.flags do
      area_$wait_in_trans;

    if (not (area_$f_active in entry^.flags)) or else
       (entry^.generation <> handle.generation) then
      status_l.all := status_$area_not_active
    else if (entry^.remote_uid = 0) and then (proc1_$as_id <> 0) and then
            (proc1_$as_id <> entry^.owner_asid) then
      status_l.all := status_$area_not_owner
    else begin
      entry^.flags := entry^.flags + [area_$f_in_trans];
      ml_$unlock(ml_$area_lock);
      max_page := rshft(entry^.virt_size - 1, 10);
      remaining := count;

      if area_$f_reversed in entry^.flags then begin
        group := -seg_idx - 1;
        start := lshft(group, 5) + page_offset;
        group_last := lshft(group, 5) + 32 - 1 - page_offset;

        { the clamp, after start is formed }
        if group_last > max_page then
          page_offset := 16#1F - (max_page & 16#1F);

        { the partial first group }
        if page_offset <> 0 then begin
          if 32 - page_offset > remaining then
            last := start + remaining - 1
          else
            last := 32 + start - page_offset - 1;
          area_$free_segments(handle.area_id, start, last, false,
                              status_l);
          if status_l.all <> status_$ok then
            goto 10;
          group := group - 1;
          remaining := remaining - (last - start + 1);
        end;

        { the whole groups below it }
        if remaining >= 32 then begin
          last := lshft(group + 1, 5) - 1;
          group := group - rshft(remaining, 5);
          start := lshft(group + 1, 5);
          area_$free_segments(handle.area_id, start, last, false,
                              status_l);
          if status_l.all <> status_$ok then
            goto 10;
          remaining := remaining - (last - start + 1);
        end;

        { the rest }
        if remaining <> 0 then begin
          first_page := lshft(group, 5);
          last_page := first_page + remaining - 1;
          area_$free_segments(handle.area_id, first_page, last_page, false,
                              status_l);
        end;
      end
      else begin
        start := lshft(seg_idx, 5) + page_offset;
        if start <= max_page then begin
          last_page := min(start + remaining - 1, max_page);
          area_$free_segments(handle.area_id, start, last_page, false,
                              status_l);
        end;
      end;

10:
      ml_$lock(ml_$area_lock);
      entry^.flags := entry^.flags - [area_$f_in_trans];
      ec_$advance(area_$in_trans_ec);
    end;

    ml_$unlock(ml_$area_lock);
  end;

  status := status_l;
end;
