{ audit_$load_list - load the audit list into the hash table.

  Image addresses:
    sau2  0x00E7131C  audit_$load_list (module-local)
    sau2  0x00E7128A  audit_$clear_hash_table (nested)
    sau2  0x00E712BA  audit_$add_to_hash (nested)

  - The list's file is locked and mapped.  Under the lock the hash table
    is emptied, the list's flags, UID, count and timeout (in 4-second
    units) taken, and each listed UID added, to the first failure.
  - True when the list was loaded (the eventcount then advanced).  A
    missing list is not an error and loads nothing.

  Status stored:
    status_$ok: the list was loaded, or there is none
    status_$audit_event_list_not_current_format: its version is above 1
    status_$audit_excessive_event_types: it has more than 256 entries
    the callees' statuses: otherwise
}

{ TODO(pascal) 12 frame bytes of audit_$load_list no object explains

  Below header's and i's slots and above the result variable's, the SAU2
  frame has 12 bytes no instruction addresses, held by the stand-ins
  unused_28 (10 bytes) and unused_2a (a word): locals the source
  declared and never used, or `with' temporaries
  for statements this reading writes without `with' (`with header^ do'
  would be one).  One 12-byte object would be placed at a multiple of 8
  from A6, where these bytes do not start, so the original's objects
  there were smaller. }

function audit_$load_list(out status: status_$t): boolean; internal;
var
  list_file_uid: uid_$t;
  map_len: integer32;
  lock_info: integer32;
  header: audit_$list_ptr_t;
  i: integer;
  unused_28: array[1..5] of integer;      { stand-in }
  unused_2a: integer;

  { audit_$clear_hash_table - empty the hash table and reset the pool.

    - The pool is reset (audit_$alloc of 0, with the parent's status)
      and the buckets cleared.
    - The loop clears the buckets 1..37; the lookups use 0..36
      (UID_$HASH's remainder by 37).
    - The SAU2 frame has 4 bytes no object explains (the stand-in
      unused_c; see the TODO(pascal) in audit/init.pas).

    Status stored: none.
  }

  procedure audit_$clear_hash_table;
  var
    i: integer;
    unused_c: integer32;                  { stand-in }
  begin
    discard(audit_$alloc(0, status));
    for i := 1 to 37 do
      audit_$hash_buckets[i] := nil;
  end;

  { audit_$add_to_hash - add a UID to the hash table.

    - A node of 12 bytes is allocated and appended, with the UID, to the
      end of its bucket's chain.

    Status stored:
      none: the pool had room
      audit_$alloc's status: a page was needed
  }

  { TODO(pascal) 12 frame bytes of audit_$add_to_hash no object explains

    The SAU2 frame holds the reserved slot, node's and link's slots, and
    12 bytes held by the stand-in unused_18 (a `with node^ do' temporary
    for the two stores would take 4 of them). }

  procedure audit_$add_to_hash(in uid: uid_$t; var status: status_$t);
  var
    node: audit_$hash_node_ptr_t;
    link: audit_$link_ptr_t;
    unused_18: array[1..3] of integer32;  { stand-in }
  begin
    node := audit_$hash_node_ptr_t(audit_$alloc(12, status));
    if status.all = status_$ok then begin
      node^.uid := uid;
      node^.next := nil;
      link := addr(audit_$hash_buckets[uid_$hash(uid, 37)]);
      while link^ <> nil do
        link := audit_$link_ptr_t(link^);
      link^ := node;
    end;
  end;

begin
  audit_$load_list := false;
  name_$resolve('`node_data/audit/audit_list', 27, list_file_uid, status);

  if status.all = name_$not_found then
    status.all := status_$ok
  else if status.all = status_$ok then begin
    file_$lock(list_file_uid, 1, 1, false, lock_info, status);
    if status.all = status_$ok then begin
      header := mst_$maps(proc1_$as_id, true, list_file_uid, 0, 16#8000,
                          16#16, 0, true, map_len, status);
      if status.all = status_$ok then begin
        if header^.version > 1 then
          status.all := status_$audit_event_list_not_current_format
        else if header^.entry_count > 256 then
          status.all := status_$audit_excessive_event_types
        else begin
          ml_$exclusion_start(audit_$wired^.lock);
          audit_$clear_hash_table;
          audit_$flags := header^.flags;
          audit_$list_uid := header^.list_uid;
          audit_$list_count := header^.entry_count;
          audit_$timeout := header^.timeout_units * 4;
          for i := 1 to audit_$list_count do begin
            audit_$add_to_hash(header^.entries[i], status);
            if status.all <> status_$ok then
              exit;
          end;
          ml_$exclusion_stop(audit_$wired^.lock);
          ec_$advance(audit_$wired^.ec);
          audit_$load_list := true;
        end;
        mst_$unmap_privi(1, uid_$nil, integer32(header), map_len, 0, status);
      end;
      discard(file_$unlock(list_file_uid, 1, status));
    end;
  end;
end;
