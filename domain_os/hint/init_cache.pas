{ HINT_$INIT_CACHE - initialize the hint lock and the local cache.

  Image addresses:
    sau2  0x00E313C8  HINT_$INIT_CACHE

  - HINT_$EXCLUSION_LOCK is initialized, both cache entries cleared and
    the round-robin index set to 1.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure hint_$init_cache;
var
  i: integer;
begin
  ml_$exclusion_init(hint_$exclusion_lock);

  for i := 1 to 2 do begin
    hint_$cache[i].uid_low_masked := 0;
    hint_$cache[i].result := false;
    hint_$cache[i].timestamp := 0;
  end;

  hint_$cache_index := 1;
end;
