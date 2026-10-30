{ ASKNODE_$GET_INFO - ask a node for information, with the default
  request length.

  Image addresses:
    sau2  0x00E645C4  ASKNODE_$GET_INFO

  - ASKNODE_$INTERNET_INFO with the request length -1, "none given".

  Status stored:
    asknode_$internet_info's status: always
}

procedure asknode_$get_info(in req_type: integer;
                            in node_id: linteger;
                            in param: univ asknode_$param_t;
                            in resp_len: integer;
                            var result: univ asknode_$info_reply_t;
                            out status: status_$t);
begin
  asknode_$internet_info(req_type, node_id, -1, param, resp_len, result,
                         status);
end;
