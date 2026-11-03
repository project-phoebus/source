{ io_$alloc_region - allocate a range of bus addresses in a bus's I/O map.

  Image addresses:
    sau3  0x00E19B5A  io_$alloc_region
    sau3  0x00E19AB8  fits (nested)
    sau5  0x00E1AE0A  io_$alloc_region
    sau5  0x00E1AD68  fits (nested)
    sau8  0x03C1BC32  io_$alloc_region
    sau8  0x03C1BB8E  fits (nested)

  - Under io_$exclusion: with fixed the range starts at iova; without,
    the first candidate that fits among lo and the addresses just
    around each range of the map.  The nested fits checks a candidate.
  - The result is assigned only when a range is allocated.

  Status stored:
    status_$ok: the range was allocated
    status_$pbu_bad_parameter: a page count of 0 or less
    status_$pbu_invalid_iova: a fixed range outside lo..hi
    status_$pbu_iomap_in_use: a fixed range overlaps one in the map
    status_$pbu_no_room_in_iomap: the map has eight ranges, or no
      candidate fits
}

function io_$alloc_region(bus: integer; lo: linteger; hi: linteger;
                          fixed: boolean; pages: integer; iova: linteger;
                          out status: status_$t): linteger;
  internal;
label
  found;
var
  cand: linteger;                         { the candidate start }
  cand_end: linteger;                     { cand + len (fits) }
  len: linteger;                          { the length in bytes }
  map: io_$iomap_ptr_t;
  i: integer;

  { Whether cand .. cand + len lies inside lo .. hi and overlaps none of
    the map's ranges; the status says why not. }
  function fits(in map: io_$iomap_t; lo: linteger;
                hi: linteger): boolean;
    options(val_param);
  var
    j: integer;
  begin
    fits := true;
    status.all := status_$ok;
    cand_end := cand + len;
    if (cand < 0) or else (cand < lo) or else (cand_end > hi) then begin
      fits := false;
      if fixed then
        status.all := status_$pbu_invalid_iova
      else
        status.all := status_$pbu_bad_parameter;
    end
    else
      for j := map.first to map.last do
        with map.ranges[j] do
          if (cand_end > start) and then (cand < stop) then begin
            status.all := status_$pbu_iomap_in_use;
            fits := false;
          end;
  end;

begin
  status.all := status_$ok;
  if pages <= 0 then
    status.all := status_$pbu_bad_parameter
  else begin
    len := pages * 1024;
    ml_$exclusion_start(io_$exclusion);
    map := io_$iomap_area.maps[bus];
    if fixed then begin
      cand := iova;
      discard(fits(map^, lo, hi));
    end
    else begin
      cand := lo;
      if not fits(map^, lo, hi) then begin
        for i := map^.first to map^.last do
          with map^.ranges[i] do begin
            cand := start - len;
            if fits(map^, lo, hi) then
              goto found;
            cand := stop;
            if fits(map^, lo, hi) then
              goto found;
          end;
        status.all := status_$pbu_no_room_in_iomap;
      end;
    end;
  found:
    if status.all = status_$ok then begin
      if map^.last = 7 then
        status.all := status_$pbu_no_room_in_iomap
      else begin
        map^.last := map^.last + 1;
        with map^.ranges[map^.last] do begin
          io_$alloc_region := cand;
          start := cand;
          stop := len + cand;
        end;
      end;
    end;
    ml_$exclusion_stop(io_$exclusion);
  end;
end;
