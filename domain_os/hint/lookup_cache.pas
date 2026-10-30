{ HINT_$LOOKUP_CACHE - look a key up in the local hint cache.

  Image addresses:
    sau2  0x00E49D06  HINT_$LOOKUP_CACHE

  - Under HINT_$EXCLUSION_LOCK the two entries are searched for the
    key.  A match gives its answer; one less than 240 ticks old (a
    signed compare) has its time refreshed and ends the search.
  - If no fresh entry matched, the answer is false.

  Status stored: none.
}

procedure hint_$lookup_cache(in uid_low_masked: linteger;
                             out result: boolean);
label
  done;
var
  i: integer;
begin
  ml_$exclusion_start(hint_$exclusion_lock);

  for i := 1 to 2 do
    if hint_$cache[i].uid_low_masked = uid_low_masked then begin
      result := hint_$cache[i].result;
      if time_$clockh - hint_$cache[i].timestamp < 240 then begin
        hint_$cache[i].timestamp := time_$clockh;
        goto done;
      end;
    end;
  result := false;

done:
  ml_$exclusion_stop(hint_$exclusion_lock);
end;
