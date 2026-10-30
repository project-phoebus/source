{ MSG_$GET_MY_NODE - this node's id.

  Image addresses:
    sau2  0x00E5912E  MSG_$GET_MY_NODE

  - NODE_$ME.

  Status stored: none.
}

procedure msg_$get_my_node(out node_id: linteger);
begin
  node_id := node_$me;
end;
