{ name/name.pas - the NAME module, the naming server's directories.

  Image addresses:
    sau2  0x00E35040  NAME data (OS_INIT_DATA, 0x108 bytes)
    sau2  0x00E80264  NAME data (.DATA, 0xB20 bytes)

  One compilation unit, `module name;': the map's NAME code segments in
  OS_INIT_PROC (NAME_$INIT), .TEXT (name_$map_dir ..
  NAME_$GET_CANNED_ROOT_UID), PROC2_CREATE_PRO (NAME_$INIT_ASID,
  NAME_$FORK) and PROC2_DELETE_PRO (NAME_$FREE_ASID), each headed with
  its sections, and its data segments in OS_INIT_DATA (264 bytes,
  NAME_$INIT's statics) and .DATA (2848 bytes).  NAMEU is name/nameu.pas.

  The .DATA block, all zero, every object a map symbol defined here:
    +0x000  NAME_$NODE_DATA_UID     uid_$t
    +0x008  NAME_$COM_MAPPED_INFO   name_$mapped_info_t (16 bytes)
    +0x018  NAME_$COM_UID           uid_$t
    +0x020  NAME_$NODE_MAPPED_INFO  name_$mapped_info_t
    +0x030  NAME_$NODE_UID          uid_$t

    +0x038  NAME_$ROOT_UID          uid_$t
    +0x040  NAME_$NDIR_MAPPED_INFO  array[0..57] of name_$mapped_info_t
    +0x3E0  NAME_$NDIR_UID          array[0..57] of uid_$t
    +0x5B0  NAME_$WDIR_MAPPED_INFO  array[0..57] of name_$mapped_info_t
    +0x950  NAME_$WDIR_UID          array[0..57] of uid_$t
  The per-address-space arrays begin at their symbols with space 0.

  The routines live in one fragment file per routine group (name/*.pas,
  misc/name_convert_acl_status.pas), included below in image order;
  name_$map_dir has a `forward' heading for NAME_$INIT.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/name/name.pas.  Check: tools/pascal_check.sh.
}
module name;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'mst/mst.ins.pas';
%include 'node/node.ins.pas';
%include 'cal/cal.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'acl/acl.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'dir/dir.ins.pas';
%include 'audit/audit.ins.pas';
%include 'name/name.ins.pas';

{ The globals this module defines (ref 7.3.4 and 7.2.2, Method 2): the
  .DATA block's objects in the block's order (above), then the routines
  in map order. }
define
  name_$node_data_uid;                    { +0x000 }
  name_$com_mapped_info;                  { +0x008 }
  name_$com_uid;                          { +0x018 }
  name_$node_mapped_info;                 { +0x020 }
  name_$node_uid;                         { +0x030 }
  name_$root_uid;                         { +0x038 }
  name_$ndir_mapped_info;                 { +0x040 }
  name_$ndir_uid;                         { +0x3E0 }
  name_$wdir_mapped_info;                 { +0x5B0 }
  name_$wdir_uid;                         { +0x950 }
  name_$init;
  name_$cleanup;
  name_convert_acl_status;
  name_$set_acl;
  name_$set_wdirus;
  name_$set_ndirus;
  name_$read_dirs_ps;
  name_$get_wdir_uid;
  name_$get_ndir_uid;
  name_$get_root_uid;
  name_$get_node_uid;
  name_$get_node_data_uid;
  name_$get_canned_root_uid;
  name_$init_asid;
  name_$fork;
  name_$free_asid;

{ name_$map_dir (name/map_dir.pas): module-local, called before its body
  by NAME_$INIT. }
{ body: name/map_dir.pas }
function name_$map_dir(dir_uid: uid_$t; asid: integer;
                       out mapped_info: name_$mapped_info_t;
                       out status: status_$t): boolean;
  forward; internal;

{ ---- OS_INIT_PROC ---- }
%include 'name/init.pas';                   { NAME_$INIT, name_$init_check_status }

{ ---- .TEXT ---- }
%include 'name/map_dir.pas';                { name_$map_dir }
%include 'name/unmap_dir_buffers.pas';      { name_$unmap_dir_buffers }
%include 'name/cleanup.pas';                { NAME_$CLEANUP }
%include 'misc/name_convert_acl_status.pas'; { NAME_CONVERT_ACL_STATUS }
%include 'name/set_acl.pas';                { NAME_$SET_ACL }
%include 'name/set_wdirus.pas';             { NAME_$SET_WDIRUS }
%include 'name/set_ndirus.pas';             { NAME_$SET_NDIRUS }
%include 'name/read_dirs_ps.pas';           { NAME_$READ_DIRS_PS }
%include 'name/get_wdir_uid.pas';           { NAME_$GET_WDIR_UID }
%include 'name/get_ndir_uid.pas';           { NAME_$GET_NDIR_UID }
%include 'name/get_root_uid.pas';           { NAME_$GET_ROOT_UID }
%include 'name/get_node_uid.pas';           { NAME_$GET_NODE_UID }
%include 'name/get_node_data_uid.pas';      { NAME_$GET_NODE_DATA_UID }
%include 'name/get_canned_root_uid.pas';    { NAME_$GET_CANNED_ROOT_UID }

{ ---- PROC2_CREATE_PRO ---- }
%include 'name/init_asid.pas';              { NAME_$INIT_ASID }
%include 'name/fork.pas';                   { NAME_$FORK }

{ ---- PROC2_DELETE_PRO ---- }
%include 'name/free_asid.pas';              { NAME_$FREE_ASID }
