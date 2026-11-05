{ vtoc_$search_volumes - look for an object on every volume.

  Image addresses:
    sau2  0x00E01BEE  vtoc_$search_volumes (module-local, AST_)
    sau4  0x0F802006  vtoc_$search_volumes (module-local, AST_)
    sau6  0x78002394  vtoc_$search_volumes (module-local, AST_)
    sau9  0x3C402FAA  vtoc_$search_volumes (module-local, AST_)

  - On a node not entirely diskless, VTOC_$LOOKUP on volumes 1..6 (not
    one AST_ is dismounting); a failure with the fail bit set goes to
    ast_$validate_uid.  A fragment of AST_.

  Status stored:
    vtoc_$lookup's status: a volume has the object
    file_$object_not_found: none has
}

procedure vtoc_$search_volumes(in out req: vtoc_$lookup_req_t;
                               out status: status_$t);
  internal;
var
  vol: integer;
begin
  if not network_$really_diskless then
    for vol := 1 to 6 do
      if not (vol in ast_$vol_info_count) then begin
        req.tail.vol_idx := vol;
        vtoc_$lookup(req, status);
        if status.all = status_$ok then
          return;
        if status.fail then
          discard(ast_$validate_uid(req.uid, status.all));
      end;

  status.all := file_$object_not_found;
end;
