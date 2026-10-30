{ NAME_$GET_ROOT_UID - hand back the root's UID.

  Image addresses:
    sau2  0x00E589BC  NAME_$GET_ROOT_UID

  - A function whose UID result goes through a hidden address: it
    stores through its one argument, and every compiled caller passes a
    temporary of its frame and copies out of it (name/name.ins.pas).
    The destination's slot is loaded first, the source's address after
    it, then the copy.

  Status stored: none.
}

function name_$get_root_uid: uid_$t;
begin
  name_$get_root_uid := name_$root_uid;
end;
