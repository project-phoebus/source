{ LOG_$ADD - append a timestamped entry to the log page.

  Image addresses:
    sau2  0x00E1763E  LOG_$ADD
    sau8  0x03C185AE  LOG_$ADD

  - Nothing is done before LOG_$INIT maps the page, nor for an entry
    over log_$max_entry_words words.
  - Under the log's spin lock the entry goes at the tail (wrapping to 1
    past the page's end), the head moved past the entries it overwrites.
  - A copy goes into LOG_$LAST_ENTRY, which outlives a crash; the log is
    marked dirty for LOG_$UPDATE.

  Status stored: none.
}

procedure log_$add(entry_type: integer; in data: univ log_$data_t;
                   data_len: integer);
  options(val_param);
var
  words: integer;
  token: integer32;
  data_words: integer;
  entry: log_$entry_ptr_t;
  buf: log_$page_ptr_t;
  now: time_$clockh_t;
  last: integer;
  size: integer;
  i: integer;
begin
  { nothing to write to before LOG_$INIT }
  if log_$logfile_ptr = nil then return;

  { the entry's size in words, header included; 1..100 words, else
    nothing is logged }
  data_words := (data_len + 1) div 2;
  words := data_words + 4;
  if (words <= 0) or else (words > log_$max_entry_words) then return;

  dirty_flag := false;
  token := ml_$spin_lock(spin_lock);
  buf := log_$logfile_ptr;

  { the entry would end past the last index: the end mark at the tail,
    and both indices back to 1 }
  last := words + buf^.tail - 1;
  if last > log_$max_index then begin
    buf^.data[buf^.tail] := 0;
    buf^.head := 1;
    buf^.tail := 1;
    last := words;
  end;

  { discard the old entries the new one overwrites }
  while (buf^.head >= buf^.tail) and then (buf^.head <= last) do begin
    size := buf^.data[buf^.head];
    if size = 0 then
      buf^.head := 1
    else begin
      buf^.head := buf^.head + size;
      if buf^.head >= log_$max_index then
        buf^.head := 1;
    end;
  end;

  { the header, in the page and in the copy }
  current_entry_ptr := addr(buf^.data[buf^.tail]);
  entry := current_entry_ptr;
  entry^.size := words;
  log_$last_entry.size := words;
  entry^.entry_type := entry_type;
  log_$last_entry.entry_type := entry_type;
  now := time_$current_clockh;
  entry^.timestamp := now;
  log_$last_entry.timestamp := now;

  { the data words, to both }
  for i := 1 to data_words do begin
    entry^.data[i] := data[i];
    log_$last_entry.data[i] := data[i];
  end;

  { the tail past the entry }
  buf^.tail := buf^.tail + words;
  if buf^.tail > log_$max_index then
    buf^.tail := 1;

  ml_$spin_unlock(spin_lock, token);
  dirty_flag := true;
end;
