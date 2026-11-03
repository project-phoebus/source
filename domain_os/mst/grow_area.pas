{ MST_$GROW_AREA - change the virtual size of the VM area an address lies
  in, mapping or unmapping its segments to match.

  Image addresses:
    sau2  0x00E4360C  MST_$GROW_AREA
    sau4  0x0F84B6E2  MST_$GROW_AREA
    sau8  0x03C4B812  MST_$GROW_AREA
    sau9  0x3C44A9D4  MST_$GROW_AREA

  - The address's MSTE must name a current anonymous area.  Growing
    maps the new segments first, then AREA_$GROW (a failure unmaps
    them); shrinking grows first, then unmaps the segments left over.
  - The undo's unmap reports into a local status, and runs also with no
    segment mapped (a zero length).

  Status stored:
    status_$ok: resized
    status_$mst_uid_not_vm_area: no anonymous area at the address
    status_$mst_object_not_found: the area's generation is stale
    the callee's status: the lookup, the mapping, AREA_$GROW or the
      shrink's unmap failed
}

procedure mst_$grow_area(in va: integer32; in new_virt_size: linteger;
                         in new_commit_size: linteger;
                         out status: status_$t);
var
  unmap_st: status_$t;
  handle: area_$handle_t;
  entry: mst_entry_ptr_t;
  start: linteger;
  map_info: integer32;
  old_size: linteger;
  addr: integer32;
  prot: pinteger;
  old_segs: pinteger;
  new_segs: pinteger;
begin
  { the MSTE of va }
  mst_$va_to_pte(proc1_$as_id, va, prot, entry, status);
  if status.all <> status_$ok then return;

  { the MSTE must name an anonymous area }
  handle := entry^.handle;
  if (entry^.uid.high <> anon_$uid.high) or else (handle.area_id = 0)
     or else (handle.area_id > area_max_entries) then begin
    status.all := status_$mst_uid_not_vm_area;
    return;
  end;

  with areas[handle.area_id] do begin
    if handle.generation <> generation then begin
      status.all := status_$mst_object_not_found;
      return;
    end;

    { the segment counts, old and new }
    old_size := virt_size;
    old_segs := (old_size + 16#7FFF) div 16#8000;
    new_segs := (new_virt_size + 16#7FFF) div 16#8000;

    { growing or shrinking }
    if old_size < new_virt_size then begin
      { growing into new segments }
      if old_segs <> new_segs then begin
        if area_$f_reversed in flags then begin
          addr := lshft(rshft(va, 15) + (16#FFFF - entry^.area_id)
                        - new_segs + 1, 15);
          start := lshft(16#10000 - new_segs, 15);
        end
        else begin
          addr := lshft(rshft(va, 15) - entry^.area_id + old_segs, 15);
          start := lshft(old_segs, 15);
        end;
        { the protection 7 and the touch count 1 pushed as one longword }
        discard(mst_$alloc_segs(addr, entry^.uid, start,
                                lshft(new_segs - old_segs, 15), 0,
                                proc1_$as_id, 7, 1, true, false, map_info,
                                status));
        if status.all <> status_$ok then return;
      end;

      { AREA_$GROW; if it fails, unmap what was mapped }
      area_$grow(handle, new_virt_size, new_commit_size, status);
      if status.all = status_$ok then return;
      { the two unmaps share one call tail }
      mst_$unmap_privi(0, entry^.uid, addr,
                       lshft(new_segs - old_segs, 15), proc1_$as_id,
                       unmap_st);
    end
    else begin
      { shrinking: AREA_$GROW, then unmap the segments it no longer
        covers }
      area_$grow(handle, new_virt_size, new_commit_size, status);
      if (status.all <> status_$ok) or else (old_segs = new_segs) then
        return;
      if area_$f_reversed in flags then
        addr := lshft(rshft(va, 15) + (16#FFFF - entry^.area_id)
                      - old_segs + 1, 15)
      else
        addr := lshft(rshft(va, 15) - entry^.area_id + new_segs, 15);
      { the two arms' common tail stores addr }
      mst_$unmap_privi(0, entry^.uid, addr,
                       lshft(old_segs - new_segs, 15), proc1_$as_id,
                       status);
    end;
  end;
end;

{ TODO(pascal) MST_$GROW_AREA against dpc

  dpc compiles the routine 42 bytes longer than the image's, which
  holds the four slots, the MSTE, the area entry and the two counts in
  registers and spills one temporary below the frame's objects. }
