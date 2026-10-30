{ NAME_$GET_NODE_DATA_UID - hand back the node-data directory's UID.

  Image addresses:
    sau2  0x00E58A00  NAME_$GET_NODE_DATA_UID

  - A function whose UID result goes through a hidden address, as
    NAME_$GET_ROOT_UID's does (name/name.ins.pas).

  Status stored: none.
}

function name_$get_node_data_uid: uid_$t;
begin
  name_$get_node_data_uid := name_$node_data_uid;
end;
