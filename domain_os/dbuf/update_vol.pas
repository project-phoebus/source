{ DBUF_$UPDATE_VOL - write every idle dirty buffer of a volume back.

  Image addresses:
    sau2  0x00E3AAA2  DBUF_$UPDATE_VOL

  - Each dirty, unreferenced, idle entry of the volume (volume 0: every
    volume) is marked busy and written back with the spin lock released;
    a failure marks the volume in DBUF_$TROUBLE.
  - The UID argument is not read.

  Status stored: none.
}

procedure dbuf_$update_vol(vol_idx: integer; in uid: uid_$t);
var
  hdr: dbuf_$hdr_t;
  status: status_$t;
  token: integer;
  i: integer;
begin
  for i := 1 to dbuf_$count do
    with dbuf[i] do
      if e_flags.dirty
         and then ((vol_idx = 0) or else (e_flags.vol = vol_idx)) then begin
        token := ml_$spin_lock(dbuf_spin_lock);

        if ((vol_idx = 0) or (e_flags.vol = vol_idx)) and then e_flags.dirty
           and then (e_ref_count = 0) and then not e_flags.busy then begin
          e_flags.busy := true;
          ml_$spin_unlock(dbuf_spin_lock, token);
          hdr.ident.uid := e_ident.uid;
          hdr.ident.hint := e_ident.hint;
          hdr.block_type := chr(e_flags.block_type);
          hdr.type_pad := chr(0);
          e_flags.dirty := false;
          disk_$write(e_flags.flags_byte & 16#0F, e_block, e_ppn, hdr,
                      status);
          if status.all <> status_$ok then
            dbuf_$trouble := dbuf_$trouble + [e_flags.vol];
          token := ml_$spin_lock(dbuf_spin_lock);
          e_flags.busy := false;
          if dbuf_$waiters <> 0 then
            ec_$advance(dbuf_$eventcount);
        end;

        ml_$spin_unlock(dbuf_spin_lock, token);
      end;
end;
