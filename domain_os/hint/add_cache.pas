{ HINT_$ADD_CACHE - put a key's answer into the local hint cache.

  Image addresses:
    sau2  0x00E49D88  HINT_$ADD_CACHE

  - Under HINT_$EXCLUSION_LOCK the key, the answer and the time of
    TIME_$CLOCKH go into the first empty cache entry; with none, into
    the entry the round-robin index (1, 2, 1, ...) steps to.

  Status stored: none.
}

procedure hint_$add_cache(in uid_low_masked: linteger; in result: boolean);
label
  done;
var
  i: integer;
begin
  ml_$exclusion_start(hint_$exclusion_lock);

  for i := 1 to 2 do
    if hint_$cache[i].uid_low_masked = 0 then begin
      hint_$cache[i].uid_low_masked := uid_low_masked;
      hint_$cache[i].result := result;
      hint_$cache[i].timestamp := time_$clockh;
      goto done;
    end;

  hint_$cache_index := hint_$cache_index + 1;
  if hint_$cache_index > 2 then hint_$cache_index := 1;
  hint_$cache[hint_$cache_index].uid_low_masked := uid_low_masked;
  hint_$cache[hint_$cache_index].result := result;
  hint_$cache[hint_$cache_index].timestamp := time_$clockh;

done:
  ml_$exclusion_stop(hint_$exclusion_lock);
end;
