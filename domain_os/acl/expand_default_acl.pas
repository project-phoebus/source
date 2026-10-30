{ acl_$expand_default_acl - expand an encoded default ACL into a
  protection record.

  Image addresses:
    sau2  0x00E45984  acl_$expand_default_acl (module-local)

  - ACL_$NIL stands for ACL_$FNDWRX; any other UID's first word must be
    1 (a file) or 2 (a directory), else the result is false.
  - The record gets the default ACL data; the encoded rights (the
    second word, bit 13 a literal word, else a directory's bits 5..8
    added) are converted into its world rights.

  Status stored: none.
}

function acl_$expand_default_acl(in out acl_uid: uid_$t;
                                 out prot: acl_$prot_data_t): boolean;
  internal;
type
  enc_t = record
    case integer of
      1: (uid: uid_$t);
      2: (acl_type: integer;                { 0x00 }
          rights: acl_$rights_word_t;       { 0x02 }
          low: integer32);                  { 0x04 }
  end;
  conv_t = packed record
    case integer of
      1: (top: 0..255;                      { bits 31..24 }
          low24: 0..16#FFFFFF);             { bits 23..0 }
      2: (all: integer32);
  end;
var
  acl_type: uid_$t;
  enc: enc_t;
  conv: conv_t;
  rights_w: acl_$rights_word_t;
begin
  if acl_uid = acl_$nil then
    enc.uid := acl_$fndwrx
  else begin
    enc.uid := acl_uid;
    if (enc.acl_type <> 1) and then (enc.acl_type <> 2) then begin
      acl_$expand_default_acl := false;
      return;
    end;
  end;

  acl_$def_acldata(prot, acl_uid);

  { the rights }
  rights_w := enc.rights;
  if 13 in rights_w then
    rights_w := rights_w - [13]
  else if enc.acl_type = 2 then
    rights_w := rights_w + [5..8];
  conv.low24 := pinteger(rights_w * [0..13]);
  conv.top := 0;

  if enc.acl_type = 1 then
    acl_type := acl_$file_acl
  else
    acl_type := acl_$dir_acl;
  prot.world_rights := acl_$rights_t(
    acl_$convert_rights(conv.all ! 16#2000000, acl_type));
  acl_$expand_default_acl := true;
end;
