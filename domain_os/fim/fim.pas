{ fim/fim.pas - the FIM_ module, the fault interrupt manager's compiled
  routines.

  Image addresses:
    sau2  0x00E2126C  FIM_ data (WIRED_DATA, 0x134 bytes)
    sau4  0x0F82287C  FIM_ data (WIRED_DATA, 0x134 bytes)
    sau7  0x3C42570C  FIM_ data (WIRED_DATA, 0x134 bytes)

  One compilation unit, one code segment and one data segment: the map's
  FIM_ code segment in WIRED_PROC (0x664 bytes, FIM_$BUILD_DF ..
  FIM_$GET_USER_PC) and its FIM_ data segment in WIRED_DATA (0x134
  bytes), whose map symbols are FIM_IN_FIM and FIM_$USER_FIM_ADDR.

  The rest of FIM is hand-written: the code inside the map's
  FIM_UNWIRED and two FIM_WIRED data segments, and FIM_$CRASH in the
  CRASH_SYSTEM data segment (fim/sau2/*.s; fim/README.md).  These
  seven routines are compiled, all global, none nested or module-local.

  The data, 0x134 bytes, zero but the frame size table at +0x124:

    +0x000  fim_in_fim          0x3A  per ASID: booleans (map symbol
                                      FIM_IN_FIM, defined here: the map
                                      lists only global symbols)
    +0x03A  unused_3a           2     nothing addresses it
    +0x03C  FIM_$USER_FIM_ADDR  0xE8  (map symbol, defined here)
    +0x124  fim_frame_size      0x10  bytes per frame format

  Module variables, not statics: four routines use the block.  The
  heading names WIRED_PROC and WIRED_DATA (LOG's model).  The names
  carry the map's FIM_ prefix.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/fim/fim.pas.  Check: tools/pascal_check.sh.
}
module fim_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'as/as.ins.pas';
%include 'acl/acl.ins.pas';
%include 'name/name.ins.pas';
%include 'peb/peb.ins.pas';
%include 'fim/fim.ins.pas';
%include 'pbu/pbu.ins.pas';

{ The global routines and the variable this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the data block (above). }
define
  fim_$build_df;
  fim_$acknowledge;
  fim_$install;
  fim_$get_fim_addr;
  fim_$init_asid;
  fim_$free_asid;
  fim_$get_user_pc;

define
  fim_in_fim;                             { +0x000 }

var
  unused_3a: integer;                     { +0x03A }

define
  fim_$user_fim_addr;                     { +0x03C }

var
  fim_frame_size: array[0..15] of fim_$byte_t := [   { +0x124 }
    16#08, 16#08, 16#0C, 0, 16#10, 0, 0, 0,
    16#3A, 16#14, 16#20, 16#5C, 0, 0, 0, 0];

{ ---- WIRED_PROC ---- }
%include 'fim/build_df.pas';                { FIM_$BUILD_DF }
%include 'fim/acknowledge.pas';             { FIM_$ACKNOWLEDGE }
%include 'fim/install.pas';                 { FIM_$INSTALL }
%include 'fim/get_fim_addr.pas';            { FIM_$GET_FIM_ADDR }
%include 'fim/init_asid.pas';               { FIM_$INIT_ASID }
%include 'fim/free_asid.pas';               { FIM_$FREE_ASID }
%include 'fim/get_user_pc.pas';             { FIM_$GET_USER_PC }
