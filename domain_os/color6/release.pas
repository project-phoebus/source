{ color6_release - drop the unit's association with its address space.

  Image addresses:
    sau7  0x3C48398C  color6_release (module-local)

  Assume we're called with the SMD request lock held.

  - The address space's mapping loses a user, and its address when the
    last is gone.

  Status stored: none.
}

procedure color6_release(info: color6_$info_ptr_t); internal;
begin
  if info^.asid <> 0 then begin
    with color6_$asid_map[info^.asid] do begin
      count := count - 1;
      if count = 0 then
        va := nil;
    end;
    info^.owner := 0;
    info^.asid := 0;
  end;
end;
