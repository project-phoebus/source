{ misc/misc.pas - the MEM_LITES module, the status lights.

  Image addresses:
    sau2  0x00E2327C  MEM_LITES data (WIRED_DATA, 0x8 bytes)

  One compilation unit, `module mem_lites, wired_proc, wired_data;': the
  map's MEM_LITES code segment in WIRED_PROC (MEM_LITES,
  START_MEM_LITES, SET_LITES_LOC) and its data segment in WIRED_DATA (8
  bytes).  misc/ is no map module; MEM_LITES is the one whose routines
  are all misc/'s, so its module file is the directory's.

  The data, 8 bytes, all zero in the image:
    +0x00  lites_loc       4 bytes (defined, the map's LITES_LOC)
    +0x04  mem_lites_row2  2 bytes
    +0x06  mem_lites_row1  2 bytes

  Build: dpc -I domain_os domain_os/misc/misc.pas.  Check:
  tools/pascal_check.sh.
}
module mem_lites, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'smd/smd.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'misc/misc.ins.pas';

{ The global routines and the variable this module defines (ref 7.3.4
  and 7.2.2, Method 2), in map order, then the module's own variables in
  the order of the block. }
define
  mem_lites;
  start_mem_lites;
  set_lites_loc;
  lites_loc;                                       { +0x00, nil }

var
  mem_lites_row2: pinteger;                        { +0x04, zero }
  mem_lites_row1: pinteger;                        { +0x06, zero }

{ ---- WIRED_PROC ---- }
%include 'misc/mem_lites.pas';               { MEM_LITES          }
%include 'misc/start_mem_lites.pas';         { START_MEM_LITES    }
%include 'misc/set_lites_loc.pas';           { SET_LITES_LOC      }
