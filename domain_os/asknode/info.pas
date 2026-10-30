{ ASKNODE_$INFO - ask a node for information, with the default lengths.

  Image addresses:
    sau2  0x00E64598  ASKNODE_$INFO

  - ASKNODE_$INTERNET_INFO with the request length -1, "none given", and
    the reply length 152.

  Status stored:
    asknode_$internet_info's status: always
}

procedure asknode_$info(in req_type: integer;
                        in node_id: linteger;
                        in param: univ asknode_$param_t;
                        var result: univ asknode_$info_reply_t;
                        out status: status_$t);
begin
  asknode_$internet_info(req_type, node_id, -1, param, 152, result,
                         status);
end;
