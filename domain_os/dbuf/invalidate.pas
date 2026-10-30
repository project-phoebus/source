{ DBUF_$INVALIDATE - drop one block, or every block, of a volume.

  Image addresses:
    sau2  0x00E3A9EC  DBUF_$INVALIDATE

  - Each entry of the volume (and, for a block other than 0, of that
    block) loses its identity, its busy and dirty bits and its
    references; a specific block ends the walk at its first match.
  - The volume's DBUF_$TROUBLE member is then removed.

  Status stored: none.
}

procedure dbuf_$invalidate(block: integer32; vol_idx: integer);
var
  token: integer;
  i: integer;
begin
  for i := 1 to dbuf_$count do
    with dbuf[i] do
      if (e_flags.vol = vol_idx)
         and then ((block = 0) or else (e_block = block)) then begin
        e_flags.vol := 0;
        e_block := -1;

        token := ml_$spin_lock(dbuf_spin_lock);
        e_flags.busy := false;
        if dbuf_$waiters <> 0 then begin
          ml_$spin_unlock(dbuf_spin_lock, token);
          ec_$advance(dbuf_$eventcount);
        end
        else
          ml_$spin_unlock(dbuf_spin_lock, token);

        e_flags.dirty := false;
        e_ref_count := 0;
        if block <> 0 then
          exit;
      end;

  dbuf_$trouble := dbuf_$trouble - [vol_idx];
end;
