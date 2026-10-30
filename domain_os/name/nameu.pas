{ name/nameu.pas - the NAMEU module, the naming server's pathname routines.

  Image addresses:
    sau2  0x00E7DB78  NAMEU data (.DATA, 0x40 bytes)

  One compilation unit, `module nameu;': the map's NAMEU code segment in
  .TEXT (name_$split_path .. NAME_$SET_WDIR) and its data segment in
  .DATA (64 bytes).  It reaches none of NAME's data and loads no A5.

  The data, two 32-byte sets of char, which no instruction addresses:
    +0x00  name_$leaf_char_set        members 33..46, 48..91, 93..126
    +0x20  name_$leaf_first_char_set  members 33..45, 48..95, 97..125
  OLD_DIR's block begins with the same 64 bytes and uses them: most
  likely one insert file's initialized variables (TODO below).

  The routines live in one fragment file per routine group, included
  below in image order; every call in the unit goes backward.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/name/nameu.pas.  Check: tools/pascal_check.sh.
}
module nameu;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'acl/acl.ins.pas';
%include 'file/file.ins.pas';
%include 'dir/dir.ins.pas';
%include 'name/name.ins.pas';

{ TODO(pascal) NAMEU's two unreferenced char sets

  The 64 bytes of the NAMEU data segment are the two sets OLD_DIR's
  block begins with, and no code addresses them in NAMEU's copy.  They
  are declared as NAMEU's initialized module variables; the original may
  have declared them in an insert file shared with OLD_DIR (a `var' with
  an initializer in each unit that includes it), or as a typed constant
  the compiler places in data.  Which, and their original names, the
  image does not say; settle with OLD_DIR's translation. }

var
  name_$leaf_char_set: set of char :=
    [chr(33)..chr(46), chr(48)..chr(91), chr(93)..chr(126)];
                                                  { +0x00 }
  name_$leaf_first_char_set: set of char :=
    [chr(33)..chr(45), chr(48)..chr(95), chr(97)..chr(125)];
                                                  { +0x20 }

define
  nameq;
  name_$validate;
  name_$resolve;
  name_$drop;
  name_$cr_file;
  name_$set_wdir;

{ ---- .TEXT ---- }
%include 'name/split_path.pas';             { name_$split_path }
%include 'name/nameq.pas';                  { NAMEQ }
%include 'name/validate.pas';               { NAME_$VALIDATE }
%include 'name/parse_component.pas';        { name_$parse_component }
%include 'name/resolve_internal.pas';       { name_$resolve_internal }
%include 'name/resolve_dir_and_leaf.pas';   { name_$resolve_dir_and_leaf }
%include 'name/resolve.pas';                { NAME_$RESOLVE }
%include 'name/drop.pas';                   { NAME_$DROP }
%include 'name/cr_file.pas';                { NAME_$CR_FILE }
%include 'name/set_wdir.pas';               { NAME_$SET_WDIR }
