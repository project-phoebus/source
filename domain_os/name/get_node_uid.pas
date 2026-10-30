{ NAME_$GET_NODE_UID - hand back the node directory's UID.

  Image addresses:
    sau2  0x00E589DE  NAME_$GET_NODE_UID

  - A function whose UID result goes through a hidden address, as
    NAME_$GET_ROOT_UID's does (name/name.ins.pas).

  Status stored: none.
}

function name_$get_node_uid: uid_$t;
begin
  name_$get_node_uid := name_$node_uid;
end;
