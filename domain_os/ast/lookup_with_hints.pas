{ ast_$lookup_with_hints - find where an object lives: on this node's
  volumes, or on a node its hints name.

  Image addresses:
    sau2  0x00E01C52  ast_$lookup_with_hints (module-local)
    sau9  0x3C40300E  ast_$lookup_with_hints (module-local)

  - A UID naming this node first searches this node's volumes.  Then
    the UID's hints are tried in order: this node's volumes once more,
    or another node asked for the object's attributes.
  - A node that answers makes the caller's location word remote, with
    the hint's network and node.

  Status stored:
    status_$ok: the object was found
    network_$install_net's status: a node answered
    file_$object_not_found: every hint failed
}

procedure ast_$lookup_with_hints(in out loc: ast_$obj_loc_view_t;
                                 in out vol: ast_$loc_word_t;
                                 out attrs: ast_$attr_rec_t;
                                 out status_ret: status_$t);
  internal;
var
  hints: ast_$hint_list_t;
  tried_local: boolean;
  hint_count: integer;
  i: integer;
begin
  { this node first }
  tried_local := false;
  if (loc.floc.uid.low & 16#FFFFF) = node_$me then begin
    vtoc_$search_volumes(loc.vtoc, status_ret);
    if status_ret.all = status_$ok then
      return;
    tried_local := true;
  end;

  hint_count := hint_$get_hints(loc.floc.uid, hints.list);

  { each hint }
  for i := 1 to hint_count do
    if hints.list[i].node_id = node_$me then begin
      if not tried_local then begin
        vtoc_$search_volumes(loc.vtoc, status_ret);
        if status_ret.all = status_$ok then
          return;
        tried_local := true;
      end;
    end
    else begin
      loc.net.node_addr := hints.addrs[i];
      loc.net.scratch := false;
      network_$ast_get_info(loc.net, 8, attrs.net, status_ret);
      if status_ret.all = status_$ok then begin
        vol.bits.remote := true;
        network_$install_net(hints.list[i].flags, vol.addr, status_ret);
        vol.bits.node := hints.list[i].node_id;
        return;
      end;
      if (loc.floc.uid.low & 16#FFFFF) = hints.list[i].node_id then
        discard(ast_$validate_uid(loc.floc.uid, status_ret.all));
    end;

  status_ret.all := file_$object_not_found;
end;
