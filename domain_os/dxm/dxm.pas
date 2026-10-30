{ dxm/dxm.pas - the DXM_WIRED_ module, the deferred execution manager.

  Image addresses:
    sau2  0x00E2A7C0  DXM_WIRED_ data (WIRED_DATA, 0x63C bytes)
    sau2  0x00E85708  DXM_WIRED_ data (DATA$, 0x8 bytes)

  One compilation unit, `module dxm_wired_, wired_proc, wired_data;':
  the map's DXM_WIRED_ code segments in WIRED_PROC, OS_INIT_PROC
  (DXM_$INIT) and PROCEDURE$ (DXM_$ADD_SIGNAL_CALLBACK, headed
  `[section(procedure$, data$)]' by its own static), and its data
  segments in WIRED_DATA (1596 bytes) and DATA$ (8 bytes).

  The data, WIRED_DATA:
    +0x000  unwired_ring   1024 bytes, 64 entries of 16, zero
    +0x400  wired_ring     512 bytes, 32 entries, zero
    +0x600  dxm_$overruns  4 bytes (defined), 0
    +0x604  dxm_$unwired_q 28 bytes (defined): mask 16#3F, the ring
    +0x620  dxm_$wired_q   28 bytes (defined): mask 16#1F, the ring

  The masks and ring pointers are initial values: nothing writes them
  at run time, and a zero mask stops the boot.  DATA$ holds
  DXM_$ADD_SIGNAL_CALLBACK's static, the two signal routines'
  addresses.

  The routines live in one fragment file each (dxm/<name>.pas), included
  below in image order within each section.

  Build: dpc -I domain_os domain_os/dxm/dxm.pas.  Check:
  tools/pascal_check.sh.
}
module dxm_wired_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'dxm/dxm.ins.pas';

{ The module's own variables (ref 3.2.2 p. 3-4, 3.11.1), in the order of
  the block, then the global routines and variables this module defines
  (ref 7.3.4 and 7.2.2, Method 2), in map order, the queues with their
  initial values. }
var
  unwired_ring: array[0..63] of dxm_$entry_t;      { +0x000, all zero }
  wired_ring: array[0..31] of dxm_$entry_t;        { +0x400, all zero }

define
  dxm_$add_callback;
  dxm_$scan_queue;
  dxm_$helper_common;
  dxm_$helper_wired;
  dxm_$helper_unwired;
  dxm_$add_signal;
  dxm_$overruns;                                   { +0x600, zero }
  dxm_$unwired_q := [mask := 16#3F,                { +0x604 }
                     entries := addr(unwired_ring)];
  dxm_$wired_q := [mask := 16#1F,                  { +0x620 }
                   entries := addr(wired_ring)];
  dxm_$init;
  dxm_$add_signal_callback;

{ ---- WIRED_PROC ---- }
%include 'dxm/add_callback.pas';            { DXM_$ADD_CALLBACK  }
%include 'dxm/scan_queue.pas';              { DXM_$SCAN_QUEUE    }
%include 'dxm/helper_common.pas';           { DXM_$HELPER_COMMON }
%include 'dxm/helper_wired.pas';            { DXM_$HELPER_WIRED }
%include 'dxm/helper_unwired.pas';          { DXM_$HELPER_UNWIRED }
%include 'dxm/add_signal.pas';              { DXM_$ADD_SIGNAL    }

{ ---- OS_INIT_PROC ---- }
%include 'dxm/init.pas';                    { DXM_$INIT          }

{ ---- PROCEDURE$ ---- }
%include 'dxm/add_signal_callback.pas';     { DXM_$ADD_SIGNAL_CALLBACK }
