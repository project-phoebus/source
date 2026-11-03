{ AST_$ACTIVATE_AND_WIRE - activate an object's segment and wire it.

  Image addresses:
    sau2  0x00E02FB8  AST_$ACTIVATE_AND_WIRE
    sau4  0x0F8033E6  AST_$ACTIVATE_AND_WIRE
    sau9  0x3C40430C  AST_$ACTIVATE_AND_WIRE

  - Under the AST lock the object's AOTE is looked up, or the object
    activated with an unknown location; then the segment's ASTE is
    looked up, or created.
  - The result is the ASTE, its wire count raised by one, or nil when
    either step failed.

  Status stored:
    status_$ok: the segment was activated and wired
    ast_$force_activate_segment's status: the object was not activated
    ast_$lookup_or_create_aste's status: the segment was not
}

function ast_$activate_and_wire(in uid: uid_$t; seg: pinteger;
                                out status: status_$t): ast_$aste_ptr_t;
label
  10;
var
  location: ast_$loc_word_t;
  aote: ast_$aote_ptr_t;
  aste: ast_$aste_ptr_t;
begin
  ml_$lock(ml_$ast_lock);
  status.all := status_$ok;

  aote := ast_$lookup_aote_by_uid(uid);
  if aote = nil then begin
    location.all := 0;
    aote := ast_$force_activate_segment(uid, location, status, false);
    if aote = nil then begin
      ast_$activate_and_wire := nil;
      goto 10;
    end;
  end;

  aste := ast_$lookup_aste(aote^, seg);
  if aste = nil then begin
    aste := ast_$lookup_or_create_aste(aote^, seg, status);
    if aste = nil then begin
      ast_$activate_and_wire := nil;
      goto 10;
    end;
  end;

  aste^.wire_count := aste^.wire_count + 1;
  ast_$activate_and_wire := aste;

10:
  ml_$unlock(ml_$ast_lock);
end;
