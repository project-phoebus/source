{ file_$uid_lock_acquire - take the per-UID bucket lock of an object.

  Image addresses:
    sau2  0x00E5D0A8  file_$uid_lock_acquire

  Assume we're called with the lock-table lock held.

  - The UID is hashed to one of 17 buckets; while another process holds
    the bucket the routine waits for FILE_$UID_LOCK_EC with the lock
    dropped, then claims it with the low byte of its process number.

  Status stored: none.
}

procedure file_$uid_lock_acquire(in uid: uid_$t); internal;
var
  ecs: ec_$waitn_ecs_t;
  wait_val: integer32;
  temp: integer32;
  hash: pinteger;
begin
  temp := xor(uid.high, uid.low);
  hash := pinteger(xor(temp, rshft(temp, 16))) mod 17;

  repeat
    if file_$uid_lock_holders[hash] = 0 then begin
      file_$uid_lock_holders[hash] := proc1_$current;
      return;
    end;
    wait_val := file_$uid_lock_ec.value + 1;
    ml_$unlock(ml_$file_lock_lock);
    ecs[1] := addr(file_$uid_lock_ec);
    discard(ec_$waitn(ecs, wait_val, 1));
    ml_$lock(ml_$file_lock_lock);
  until false;
end;
