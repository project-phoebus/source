{ HINT_$ADDU - record one object's hints for another under the hint
  lock.

  Image addresses:
    sau2  0x00E49C08  HINT_$ADDU

  - If the hint file is published and the two UIDs' keys differ, the
    source's first hint is recorded for the target under
    HINT_$EXCLUSION_LOCK.
  - Only the source's first hint is recorded.

  Status stored: none.
}

procedure hint_$addu(in target_uid: uid_$t; in source_uid: uid_$t);
var
  addresses: hint_$addr_list_t;
begin
  if hint_$hintfile_ptr = nil then return;
  if (target_uid.low & 16#FFFFF) = (source_uid.low & 16#FFFFF) then return;

  discard(hint_$get_hints(source_uid, addresses));
  ml_$exclusion_start(hint_$exclusion_lock);
  hint_$add_internal(target_uid, addresses[1]);
  ml_$exclusion_stop(hint_$exclusion_lock);
end;
