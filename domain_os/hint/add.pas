{ HINT_$ADD - record a hint for a node under the hint lock.

  Image addresses:
    sau2  0x00E49BB8  HINT_$ADD

  - If the hint file is published, a hint for the node with flags 0 is
    recorded under HINT_$EXCLUSION_LOCK.

  Status stored: none.
}

procedure hint_$add(in uid: uid_$t; in node_id: linteger);
var
  local_addr: hint_$addr_t;
begin
  if hint_$hintfile_ptr = nil then return;
  local_addr.node_id := node_id;
  local_addr.flags := 0;

  ml_$exclusion_start(hint_$exclusion_lock);
  hint_$add_internal(uid, local_addr);
  ml_$exclusion_stop(hint_$exclusion_lock);
end;
