{ ast_$purify_aote - write an object's attributes back.

  Image addresses:
    sau2  0x00E013A0  ast_$purify_aote (module-local)
    sau4  0x0F8017B0  ast_$purify_aote (module-local)
    sau9  0x3C40279C  ast_$purify_aote (module-local)

  Assume we're called with the AST lock held.

  - A touched remote object that is not read-only gets its DTU from its
    home node's fresh attributes (the touch mark put back on failure).
  - A touched local object gets the current time as its DTU and is
    marked dirty; a dirty one's attribute record is written with
    VTOCE_$WRITE, the AST lock released around the call.

  Status stored:
    status_$ok: the attributes were written, or needed not be (also
      when the disk is write protected, and on the remote path)
    vtoce_$write's status, with the fail bit: the write failed
}

procedure ast_$purify_aote(var aote: univ ast_$aote_view_t; flags: boolean;
                           out status_ret: status_$t);
  internal;
var
  attrs: ast_$attr_rec_t;
  local_status: status_$t;
begin
  status_ret.all := status_$ok;

  if aote.aote.loc.remote then begin
    if not (4 in aote.aote.flags) then
      return;
    if 0 in aote.attrs.common.attr_flags_lo then
      return;

    aote.aote.flags := aote.aote.flags - [4];
    ml_$unlock(ml_$ast_lock);
    network_$ast_get_info(aote.obj_loc.net, 16#80, attrs.net, local_status);
    ml_$lock(ml_$ast_lock);

    if local_status.all = status_$ok then begin
      ml_$lock(ml_$pmap_lock);
      aote.aote.dtu := attrs.fattr.clock_24;
      ml_$unlock(ml_$pmap_lock);
    end
    else
      aote.aote.flags := aote.aote.flags + [4];
  end
  else begin
    { a touched object gets a new DTU }
    if 4 in aote.aote.flags then begin
      aote.aote.flags := aote.aote.flags - [4];
      ml_$lock(ml_$pmap_lock);
      time_$clock(aote.aote.dtu);
      ml_$unlock(ml_$pmap_lock);
      aote.aote.flags := aote.aote.flags + [5];
    end;

    { a dirty one is written back }
    if 5 in aote.aote.flags then begin
      aote.aote.flags := aote.aote.flags - [5];
      attrs := aote.attrs;
      ml_$unlock(ml_$ast_lock);
      vtoce_$write(aote.obj_loc.vtoc, attrs.vtoce, flags, status_ret);
      ml_$lock(ml_$ast_lock);
      if status_ret.all <> status_$ok then
        if status_ret.all = status_$disk_write_protected then
          status_ret.all := status_$ok
        else begin
          status_ret.fail := true;
          aote.aote.flags := aote.aote.flags + [5];
        end;
    end;
  end;
end;
