{ volx/volx.pas - the VOLX_ module, the volume mount table.

  Image addresses:
    sau2  0x00E82604  VOLX_ data (.DATA, 0xC0 bytes)

  One compilation unit, one code segment and one data segment: the map's
  VOLX_ code segment in .TEXT (0x620 bytes, FIND_VOLX ..
  VOLX_$REC_ENTRY) and its VOLX_ data segment in .DATA (0xC0 bytes).

  All seven routines are global: FIND_VOLX's map symbol has no `$', but
  the map lists only global symbols (volx/find_volx.pas).

  The data, 0xC0 bytes, all zero in the image: the mount table, six
  0x20-byte entries from 1, the one module variable.  The segment
  exports no symbol.  The code is .TEXT's and the block .DATA's, so the
  heading names no sections.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/volx/volx.pas.  Check: tools/pascal_check.sh.
}
module volx_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'name/name.ins.pas';
%include 'disk/disk.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'dir/dir.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'bat/bat.ins.pas';
%include 'cal/cal.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'volx/volx.ins.pas';

{ The global routines this module defines (ref 7.3.4), in map order. }
define
  find_volx;
  volx_$mount;
  volx_$dismount;
  volx_$shutdown;
  volx_$get_info;
  volx_$get_uids;
  volx_$rec_entry;

var
  volx_$table: array[1..volx_max_volumes] of volx_$entry_t;   { +0x00 }

{ ---- .TEXT ---- }
%include 'volx/find_volx.pas';              { FIND_VOLX }
%include 'volx/mount.pas';                  { VOLX_$MOUNT }
%include 'volx/dismount.pas';               { VOLX_$DISMOUNT }
%include 'volx/shutdown.pas';               { VOLX_$SHUTDOWN }
%include 'volx/get_info.pas';               { VOLX_$GET_INFO }
%include 'volx/get_uids.pas';               { VOLX_$GET_UIDS }
%include 'volx/rec_entry.pas';              { VOLX_$REC_ENTRY }
