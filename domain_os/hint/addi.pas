{ HINT_$ADDI - record a hint pair under the hint lock.

  Image addresses:
    sau2  0x00E49B74  HINT_$ADDI

  - If the hint file is published, the hint is recorded under
    HINT_$EXCLUSION_LOCK.

  Status stored: none.
}

procedure hint_$addi(in uid: uid_$t; in addresses: hint_$addr_t);
begin
  if hint_$hintfile_ptr = nil then return;
  ml_$exclusion_start(hint_$exclusion_lock);
  hint_$add_internal(uid, addresses);
  ml_$exclusion_stop(hint_$exclusion_lock);
end;
