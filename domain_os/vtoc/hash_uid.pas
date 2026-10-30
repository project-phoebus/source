{ vtoc_$hash_uid - the VTOC block (and bucket) of a UID.

  Image addresses:
    sau2  0x00E383B0  vtoc_$hash_uid (module-local)

  - The hash by the volume's hash type (2, below 2 UID_$HASH, 3); on a
    new-format volume its low two bits are the bucket.  The volume's
    partitions turn the index into a block.
  - A hash type above 3 leaves the hash unassigned.

  Status stored:
    status_$ok: a block was found
    status_$vtoc_is_bad: the block is 0
}

procedure vtoc_$hash_uid(in uid: univ vtoc_$uid_view_t; vol_idx: integer;
                         out bucket_idx: univ pinteger;
                         out block: linteger;
                         out status: status_$t);
  internal;
var
  x: integer32;
  hash: pinteger;
  i: integer;
begin
  status.all := status_$ok;

  with vtoc_$vols[vol_idx] do begin
    { the hash }
    if hash_type = 2 then begin
      x := uid.uid.high + uid.uid.high;
      if uid.uid.low < 0 then
        x := x + 1;
      hash := (xor(x & 16#FFFF, rshft(x, 16)) & 16#FFFF) mod hash_size;
    end
    else if hash_type < 2 then
      hash := uid_$hash(uid.uid, hash_size)
    else if hash_type = 3 then begin
      x := uid.uid.high;
      hash := xor(x & 16#FFFF, rshft(x, 16));
      hash := hash mod hash_size;
    end;

    { the block of the index }
    if vtoc_$format[vol_idx] then begin
      bucket_idx := hash & 3;
      hash := rshft(hash, 2);
      block := 0;
      for i := 0 to 9 do begin
        if hash < parts[i].count then begin
          block := hash + parts[i].base;
          exit;
        end;
        hash := hash - parts[i].count;
      end;
    end
    else begin
      block := 0;
      for i := 0 to 7 do begin
        if hash < parts[i].count then begin
          block := hash + parts[i].base;
          exit;
        end;
        hash := hash - parts[i].count;
      end;
    end;
  end;

  if block = 0 then
    status.all := status_$vtoc_is_bad;
end;
