{ DBUF_$SET_BUFF - release and/or write back a buffer.

  Image addresses:
    sau2  0x00E3A8B6  DBUF_$SET_BUFF

  - The buffer's entry is found under the spin lock (none crashes the
    system).  The flags then ask, in order: mark it dirty, write it back
    if dirty, invalidate it, release one reference (none left crashes).
  - A failed write-back marks the volume in DBUF_$TROUBLE.

  Status stored:
    status_$ok: the entry was found and no write-back failed
    disk_$write's status: the write-back failed
}

procedure dbuf_$set_buff(buffer: univ_ptr; flags: integer;
                         out status: status_$t);
var
  hdr: dbuf_$hdr_t;
  e: dbuf_$entry_ptr_t;
  token: integer;
begin
  token := ml_$spin_lock(dbuf_spin_lock);
  e := dbuf_$head;

  repeat
    if e^.e_data = buffer then begin
      ml_$spin_unlock(dbuf_spin_lock, token);
      status.all := status_$ok;

      if (flags & dbuf_flag_dirty) <> 0 then
        e^.e_flags.dirty := true;

      if ((flags & dbuf_flag_writeback) <> 0) and then e^.e_flags.dirty then begin
        hdr.ident.bytes := e^.e_ident.bytes;
        hdr.block_type := chr(e^.e_flags.block_type);
        hdr.type_pad := chr(0);
        e^.e_flags.dirty := false;
        disk_$write(e^.e_flags.flags_byte & 16#0F, e^.e_block, e^.e_ppn,
                    hdr, status);
        if status.all <> status_$ok then
          dbuf_$trouble := dbuf_$trouble + [e^.e_flags.vol];
      end;

      if (flags & dbuf_flag_invalidate) <> 0 then begin
        e^.e_flags.vol := 0;
        e^.e_block := -1;
        e^.e_flags.dirty := false;
      end;

      if (flags & dbuf_flag_release) <> 0 then begin
        if e^.e_ref_count = 0 then
          crash_system(os_dbuf_bad_free_err);
        e^.e_ref_count := e^.e_ref_count - 1;
        if (e^.e_ref_count = 0) and then (dbuf_$waiters <> 0) then
          ec_$advance(dbuf_$eventcount);
      end;
      return;
    end;
    e := e^.e_next;
  until e = nil;

  ml_$spin_unlock(dbuf_spin_lock, token);
  crash_system(os_dbuf_bad_ptr_err);
end;
