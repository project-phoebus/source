{ MSG_$GET_MY_NET - this node's network.

  Image addresses:
    sau2  0x00E5911C  MSG_$GET_MY_NET

  - The network of routing port 0.

  Status stored: none.
}

procedure msg_$get_my_net(out net_id: integer32);
begin
  net_id := route_$port[0].network;
end;
