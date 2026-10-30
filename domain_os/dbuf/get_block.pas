{ DBUF_$GET_BLOCK - look a disk block up in the buffer cache, reading it
  in.

  Image addresses:
    sau2  0x00E3A5B0  DBUF_$GET_BLOCK

  - Under the spin lock the LRU list is searched for the volume's block;
    a hit that is busy is waited for, else it moves to the head and its
    buffer is the result.
  - On a miss the least recent idle entry is claimed (a dirty one
    written back first, a failure marking the volume in DBUF_$TROUBLE)
    and the block read in, unless the caller says not to.
  - A failed read gives the buffer up and the result is nil.

  Status stored:
    status_$ok: the block's buffer was returned
    disk_$read's status, with the fail bit: the read failed (a stopped
      storage module the caller accepts excepted)
}

{ TODO(pascal) the result variable between e and token in the frame

  In the SAU2 frame token lies below 4 bytes nothing addresses, with
  e's slot above them and the result held in a register.  The
  result variable there, between the locals, fits the frame; dpc puts it
  below the locals (the result's place
  Uncertain). }

{ TODO(pascal) the flags word's busy and dirty bits tested through the
  word

  The SAU2 image tests busy as the sign of the flags word and dirty as
  bit 14 of the loaded word, where a boolean field of a packed record is
  tested through its byte.  The stores are byte
  forms.  The word forms are those of whole-value set tests;
  a packed record read whole, or a variant with a word view, would
  explain them.  Also: `e_flags.vol := vol_idx' ORs the whole low byte
  of vol_idx in, not masked to 4 bits, the form of a value whose type
  the compiler trusts to fit (a 0..15 parameter); vol_idx is integer in
  the reviewed heading. }

function dbuf_$get_block(vol_idx: integer; block: integer32;
                         in uid: uid_$t; block_hint: integer32;
                         block_type: integer; flags: integer;
                         out status: status_$t): univ_ptr;
label
  retry, wait;
var
  hdr: dbuf_$hdr_t;
  wait_value: integer32;
  e: dbuf_$entry_ptr_t;
  token: integer;
begin
  status.all := status_$ok;

  if netlog_$ok_to_log then
    netlog_$log_it(16#10, uid, rshft(block_hint, 5), block_hint & 16#1F,
                   block_type, vol_idx, 0, 0);

  { the outer loop; its head the target of the wait's `goto retry' }
retry:
  repeat
    token := ml_$spin_lock(dbuf_spin_lock);

    { the search }
    repeat
      wait_value := dbuf_$eventcount.value + 1;
      e := dbuf_$head;

      { the cache lookup, head to tail }
      repeat
        if (e^.e_block = block) and then (e^.e_flags.vol = vol_idx) then begin
          if e^.e_flags.busy then
            goto wait;
          e^.e_ref_count := e^.e_ref_count + 1;
          if (flags & dbuf_get_no_read) <> 0 then begin
            e^.e_ident.uid := uid;
            e^.e_ident.hint := block_hint;
            e^.e_flags.block_type := block_type;
          end;
          if e^.e_prev <> nil then begin
            e^.e_prev^.e_next := e^.e_next;
            if e^.e_next <> nil then
              e^.e_next^.e_prev := e^.e_prev;
            dbuf_$head^.e_prev := e;
            e^.e_next := dbuf_$head;
            e^.e_prev := nil;
            dbuf_$head := e;
          end;
          dbuf_$get_block := e^.e_data;
          ml_$spin_unlock(dbuf_spin_lock, token);
          return;
        end;
        if e^.e_next = nil then
          exit;
        e := e^.e_next;
      until false;

      { back from the tail to a free entry }
      repeat
        if (e^.e_ref_count = 0) and then not e^.e_flags.busy then
          exit;
        if e^.e_prev = nil then
          goto wait;
        e := e^.e_prev;
      until false;

      if e^.e_flags.dirty then begin
        { write the dirty victim back; the `then' part's closing jump
          and the inner `if''s false branch go to the same target }
        e^.e_flags.busy := true;
        ml_$spin_unlock(dbuf_spin_lock, token);
        hdr.ident.bytes := e^.e_ident.bytes;
        hdr.block_type := chr(e^.e_flags.block_type);
        hdr.type_pad := chr(0);
        e^.e_flags.dirty := false;
        disk_$write(e^.e_flags.flags_byte & 16#0F, e^.e_block, e^.e_ppn,
                    hdr, status);
        if status.all <> status_$ok then begin
          dbuf_$trouble := dbuf_$trouble + [e^.e_flags.vol];
          status.all := status_$ok;
        end;
      end
      else begin
        { move the clean victim to the head }
        if e^.e_prev <> nil then begin
          e^.e_prev^.e_next := e^.e_next;
          if e^.e_next <> nil then
            e^.e_next^.e_prev := e^.e_prev;
          dbuf_$head^.e_prev := e;
          e^.e_next := dbuf_$head;
          e^.e_prev := nil;
          dbuf_$head := e;
        end;

        { claim it }
        e^.e_flags.vol := vol_idx;
        e^.e_block := block;
        e^.e_ident.uid := uid;
        e^.e_ident.hint := block_hint;
        e^.e_flags.block_type := block_type;
        e^.e_flags.busy := true;
        ml_$spin_unlock(dbuf_spin_lock, token);

        { read it in }
        if (flags & dbuf_get_no_read) = 0 then begin
          hdr.ident.uid := uid;
          hdr.ident.hint := block_hint;
          disk_$read(vol_idx, block, e^.e_ppn, hdr, status);

          { two branches to the end, one into the body }
          if status.all <> status_$ok then
            if ((flags & dbuf_get_ok_if_stopped) = 0)
               or else (status.all <> status_$storage_module_stopped) then begin
              { give the buffer up }
              e^.e_flags.vol := 0;
              e^.e_block := -1;
              token := ml_$spin_lock(dbuf_spin_lock);
              e^.e_flags.busy := false;
              if dbuf_$waiters <> 0 then begin
                ml_$spin_unlock(dbuf_spin_lock, token);
                ec_$advance(dbuf_$eventcount);
              end
              else
                ml_$spin_unlock(dbuf_spin_lock, token);
              status.fail := true;
              dbuf_$get_block := nil;
              return;
            end;
        end;
      end;

      { the settle }
      token := ml_$spin_lock(dbuf_spin_lock);
      e^.e_flags.busy := false;
    until dbuf_$waiters <> 0;

    ml_$spin_unlock(dbuf_spin_lock, token);
    ec_$advance(dbuf_$eventcount);
  until false;

wait:
  dbuf_$waiters := dbuf_$waiters + 1;
  ml_$spin_unlock(dbuf_spin_lock, token);
  discard(ec_$wait(addr(dbuf_$eventcount), addr(ec_$nil_ec),
                   addr(ec_$nil_ec), wait_value, 0, 0));
  dbuf_$waiters := dbuf_$waiters - 1;
  goto retry;
end;
