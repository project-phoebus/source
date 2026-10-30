{ dir_$old_hash_name - hash an entry name to its old-format bucket.

  Image addresses:
    sau2  0x00E54B58  dir_$old_hash_name (module-local)

  - Each byte doubles the hash and adds itself, in 16 bits; the bucket is
    the hash mod the bucket count, unsigned.

  Status stored: none.
}

function dir_$old_hash_name(in name: univ name_$long_name_t;
                            name_len: pinteger;
                            buckets: pinteger): pinteger;
  internal;
var
  h: pinteger;
  i: pinteger;
begin
  h := 0;

  for i := 1 to name_len do
    h := h + h + ord(name[i]);

  dir_$old_hash_name := h mod buckets;
end;
