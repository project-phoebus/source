{ FILE_$PRIV_UNLOCK_ALL - release every lock of one address space, or of
  all of them.

  Image addresses:
    sau2  0x00E60BD0  FILE_$PRIV_UNLOCK_ALL
    sau9  0x3C467A54  FILE_$PRIV_UNLOCK_ALL

  - Address space 0 means all 58 (0..57), and then the remote locks go
    too (REM_FILE_$UNLOCK_ALL).
  - Under the lock-table lock each used slot is released: a shared
    entry loses one use, a sole one goes to FILE_$PRIV_UNLOCK with the
    table lock dropped.  Each list's count is then cleared.

  Status stored: none.
}

{ TODO(pascal) FILE_$PRIV_UNLOCK_ALL's inner `for': a signed guard, a
  zero-extended index

  The inner loop's guard is signed, but its index is widened with zeros
  for FILE_$PRIV_UNLOCK's longword lock_slot.  FILE_$UNLOCK_PROC's loop
  over the same bound has the same guard and widens its index with its
  sign for the same formal, so there the index is an integer.  A
  pinteger index with a pinteger bound gives the unsigned guard (dpc says
  so), not this one.  Both forms fit if
  file_$lock_table2's elements are integer (a signed bound), which
  FILE_$PRIV_UNLOCK's guard and this file's other loops over it also
  allow; they were made pinteger for priv_lock_alloc_entry's unsigned
  compare with the count, which an unsigned index compared with a signed
  bound may give as well.  Here slot is pinteger and the bound pinteger,
  as declared; the element type is not settled. }

procedure file_$priv_unlock_all(in asid: integer);
var
  local_uid: uid_$t;
  dtv: time_$clock_t;
  local_status: status_$t;
  first: integer;
  last: integer;
  a: integer;
  slot: pinteger;
begin
  if asid = 0 then begin
    first := 0;
    last := 16#39;
  end
  else begin
    first := asid;
    last := first;
  end;

  ml_$lock(ml_$file_lock_lock);
  for a := first to last do begin
    for slot := 1 to file_$lock_table2[a] do
      if file_$lock_table[a, slot] <> 0 then
        with file_$lock_entries[file_$lock_table[a, slot]] do
          if state.refcount > 1 then begin
            file_$lock_table[a, slot] := 0;
            state.refcount := state.refcount - 1;
          end
          else begin
            local_uid := uid;
            ml_$unlock(ml_$file_lock_lock);
            discard(file_$priv_unlock(local_uid, slot, 0, a, false, 0, 0, 0,
                                      dtv, local_status));
            ml_$lock(ml_$file_lock_lock);
          end;
    file_$lock_table2[a] := 0;
  end;

  ml_$unlock(ml_$file_lock_lock);
  if asid = 0 then
    rem_file_$unlock_all;
end;
