{ AST_$MSTE_ACTIVATE_AND_WIRE - activate an MSTE's segment and wire it.

  Image addresses:
    sau2  0x00E02F34  AST_$MSTE_ACTIVATE_AND_WIRE
    sau4  0x0F803362  AST_$MSTE_ACTIVATE_AND_WIRE
    sau6  0x78003698  AST_$MSTE_ACTIVATE_AND_WIRE
    sau7  0x3C403A88  AST_$MSTE_ACTIVATE_AND_WIRE
    sau9  0x3C404288  AST_$MSTE_ACTIVATE_AND_WIRE

  - As AST_$ACTIVATE_AND_WIRE, for an MSTE's UID, location word (not
    forced) and segment, without taking the AST lock.
  - The result is the ASTE, its wire count raised by one, or nil.

  Status stored:
    status_$ok: the segment was activated and wired
    ast_$force_activate_segment's status: the object was not activated
    ast_$lookup_or_create_aste's status: the segment was not
}

function ast_$mste_activate_and_wire(in mste: ast_$mste_t;
                                     out status: status_$t):
  ast_$aste_ptr_t;
var
  aote: ast_$aote_ptr_t;
  aste: ast_$aste_ptr_t;
begin
  status.all := status_$ok;

  aote := ast_$lookup_aote_by_uid(mste.uid);
  if aote = nil then begin
    aote := ast_$force_activate_segment(mste.uid,
                                        ast_$loc_word_t(mste.location),
                                        status, false);
    if aote = nil then begin
      ast_$mste_activate_and_wire := nil;
      return;
    end;
  end;

  aste := ast_$lookup_aste(aote^, mste.segment);
  if aste = nil then begin
    aste := ast_$lookup_or_create_aste(aote^, mste.segment, status);
    if aste = nil then begin
      ast_$mste_activate_and_wire := nil;
      return;
    end;
  end;

  aste^.wire_count := aste^.wire_count + 1;
  ast_$mste_activate_and_wire := aste;
end;
