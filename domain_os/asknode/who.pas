{ ASKNODE_$WHO - list the nodes of this node's network.

  Image addresses:
    sau2  0x00E65F78  ASKNODE_$WHO

  - ASKNODE_$WHO_REMOTE for this node on the home network; when the
    network hardware cannot do it, ASKNODE_$WHO_NOTOPO.  The status is
    dropped.

  Status stored: none.
}

procedure asknode_$who(out node_list: asknode_$node_list_t;
                       in max_count: integer;
                       out count: pinteger);
var
  status: status_$t;
begin
  asknode_$who_remote(node_$me, route_$port[0].network, node_list,
                      max_count, count, status);

  if status.all = status_$network_operation_not_defined_on_hardware then
    asknode_$who_notopo(node_$me, route_$port[0].network, node_list,
                        max_count, count, status);
end;
