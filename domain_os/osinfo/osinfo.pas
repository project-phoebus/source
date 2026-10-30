{ osinfo/osinfo.pas - the OSINFO module, the memory-management queries.

  One compilation unit, one code segment (the map's OSINFO segment in
  .TEXT: OSINFO_$GET_SEG_TABLE, OSINFO_$GET_MMAP) and no data: the
  routines read other units' objects by their absolute addresses.

  Build: dpc -I domain_os domain_os/osinfo/osinfo.pas.  Check:
  tools/pascal_check.sh.
}
module osinfo;

%include 'base/base.ins.pas';
%include 'ml/ml.ins.pas';                  { for pmap.ins.pas's MOUNT_LOCK }
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'pmap/pmap.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'osinfo/osinfo.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  osinfo_$get_seg_table;
  osinfo_$get_mmap;

{ ---- .TEXT ---- }
%include 'osinfo/get_seg_table.pas';        { OSINFO_$GET_SEG_TABLE }
%include 'osinfo/get_mmap.pas';             { OSINFO_$GET_MMAP }
