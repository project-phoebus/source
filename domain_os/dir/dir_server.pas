{ dir/dir_server.pas - the DIR_SERVER module, the remote directory
  server's request handler.

  Image addresses:
    sau2  0x00E801E4  DIR_SERVER data (.DATA, 0x80 bytes)

  One compilation unit: the map's DIR_SERVER code segment in .TEXT
  (DIR_$SERVER and a 2-byte zero cell after it) and its data segment in
  .DATA (128 bytes), which only DIR_$SERVER addresses: the block's
  objects are its statics (dir/server.pas).

  DIR_$SERVER's heading and its request and reply records are in
  dir/dir_server.ins.pas, which REM_FILE_$SERVER's module includes too.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/dir/dir_server.pas.  Check: tools/pascal_check.sh.
}
module dir_server;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'rgyc/rgyc.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'name/name.ins.pas';
%include 'dir/dir.ins.pas';
%include 'rem_file/rem_file.ins.pas';
%include 'dir/dir_server.ins.pas';

type
  { A pointer to a project list (acl/eval_rights.pas proj_ptr_t's
    shape), for DIR_$SERVER's last ACL_$SET_PROJ_LIST, whose list is
    UID_$NIL (see dir/server.pas). }
  dir_$proj_uids_ptr_t = ^acl_$proj_uids_t;

{ The global routine this module defines (ref 7.3.4, Method 2). }
define
  dir_$server;

{ ---- .TEXT ---- }
%include 'dir/server.pas';                   { DIR_$SERVER }
