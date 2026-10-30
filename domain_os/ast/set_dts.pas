{ AST_$SET_DTS - set an object's clocks.

  Image addresses:
    sau2  0x00E05540  AST_$SET_DTS
    sau9  0x3C4067EA  AST_$SET_DTS

  - Inhibited and under the AST lock, the object's AOTE is looked up, or
    the object activated when bit 0 of flags asks for it.
  - With bit 4, a touched AOTE loses its mark and a local one gets a
    fresh DTU; the result is then true.  Otherwise bit 1 sets the DTV,
    bit 2 the DTM and DTA, bit 3 the DTU.

  Status stored:
    status_$ok: the clocks were set, or the object is not active
    ast_$force_activate_segment's status: the object was not activated
}

function ast_$set_dts(flags: integer; uid: uid_$t; in dtv: time_$clock_t;
                      in access_time: time_$clock_t;
                      out status: status_$t): boolean;
label
  10;
var
  local_status: status_$t;
  location: ast_$loc_word_t;
  aote: ast_$aote_ptr_t;
begin
  local_status.all := status_$ok;
  ast_$set_dts := false;
  proc1_$inhibit_begin;
  ml_$lock(ml_$ast_lock);

  aote := ast_$lookup_aote_by_uid(uid);
  if (aote = nil) and then (0 in ast_$word_set_t(flags)) then begin
    location.all := 0;
    aote := ast_$force_activate_segment(uid, location, local_status,
                                        true);
  end;
  if aote = nil then
    goto 10;

  if (4 in ast_$word_set_t(flags)) and then (4 in aote^.flags) then begin
    { touched }
    ast_$set_dts := true;
    aote^.flags := aote^.flags - [4];
    if aote^.loc.remote then
      goto 10;
    ml_$lock(ml_$pmap_lock);
    time_$clock(aote^.dtu);
  end
  else begin
    ml_$lock(ml_$pmap_lock);
    if 1 in ast_$word_set_t(flags) then
      aote^.dtv := dtv;
    if 2 in ast_$word_set_t(flags) then begin
      aote^.dtm := access_time;
      aote^.dta := access_time;
    end;
    if 3 in ast_$word_set_t(flags) then
      aote^.dtu := access_time;
  end;

  aote^.flags := aote^.flags + [5];
  ml_$unlock(ml_$pmap_lock);

10:
  ml_$unlock(ml_$ast_lock);
  proc1_$inhibit_end;
  status := local_status;
end;
