{ file_$uid_lock_release - give back the per-UID bucket lock of an object.

  Image addresses:
    sau2  0x00E5D134  file_$uid_lock_release

  - The UID's bucket (as file_$uid_lock_acquire hashes it) loses its
    holder, and FILE_$UID_LOCK_EC is advanced for the waiters.

  Status stored: none.
}

procedure file_$uid_lock_release(in uid: uid_$t); internal;
var
  temp: integer32;
  hash: pinteger;
begin
  temp := xor(uid.high, uid.low);
  hash := pinteger(xor(temp, rshft(temp, 16))) mod 17;

  file_$uid_lock_holders[hash] := 0;
  ec_$advance(file_$uid_lock_ec);
end;
