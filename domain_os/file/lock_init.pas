{ FILE_$LOCK_INIT - set up the lock tables at boot.

  Image addresses:
    sau2  0x00E32744  FILE_$LOCK_INIT
    sau9  0x3C438E78  FILE_$LOCK_INIT

  - Every address space's lock list (150 slots) is cleared, the 1792
    entries of the lock object table threaded onto the free list, and
    the 251 hash buckets cleared.
  - The lock eventcount is initialized, the module's UID and the base
    UID (this node's number in UID_$NIL's low 20 bits) formed; every
    lock this node holds on remote objects is dropped.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure file_$lock_init;
var
  asid: integer;                          { (the count only) }
  slot: integer;                          { (the count only) }
  index: integer;
  i: integer;                             { (the count only) }
begin
  { the address spaces' lists and counts }
  for asid := 0 to 57 do begin
    for slot := 1 to 150 do
      file_$lock_table[asid, slot] := 0;
    file_$lock_table2[asid] := 0;
  end;

  { the free list }
  for index := 1 to 1792 do begin
    file_$lock_entries[index].state.refcount := 0;
    file_$lock_entries[index].next := index + 1;
  end;

  { the list ends at the last entry }
  file_$lock_entries[1792].next := 0;

  file_$lot_free := 1;
  for i := 0 to 250 do
    file_$lot_hashtab[i] := 0;

  ec_$init(file_$uid_lock_ec);
  file_$lot_free := 1;
  file_$lot_high := 1;
  uid_$gen(file_$generated_uid);

  { UID_$NIL with this node in its low 20 bits }
  file_$base_uid.uid := uid_$nil;
  file_$base_uid.low.node := node_$me;

  file_$lot_full := false;
  rem_file_$unlock_all;
end;
