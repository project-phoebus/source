{ xpd/xpd.pas - the XPD module, the cross-process debug manager.

  Image addresses:
    sau2  0x00E35148  XPD data (OS_INIT_DATA, 0x4 bytes)
    sau2  0x00E81810  XPD data (.DATA, 0x4 bytes)
    sau2  0x00EA5034  XPD_$DATA (overlay section, 0x4E8 bytes)

  One compilation unit: the map's XPD code segments in OS_INIT_PROC
  (0x90 bytes, XPD_$INIT), .TEXT (0x126C bytes, XPD_$FIND_INDEX ..
  XPD_$GET_TARGET_INFO) and PROC2_DELETE_PRO (0x1BC bytes,
  xpd_$unregister_debugger, XPD_$CLEANUP, XPD_$POST_EVENT), and its
  data segments in OS_INIT_DATA and .DATA (4 bytes each, zero, no
  objects of the source).  XPD_KER is xpd/xpd_ker.pas.

  The heading names no section; XPD_$INIT is headed
  `[section(os_init_proc, os_init_data)]', the three of
  PROC2_DELETE_PRO `[section(proc2_delete_pro, proc2_delete_dat)]'.

  XPD_$DATA, an overlay section, holds two adjacent tables:

    +0x000  xpd_$targets    58 * 0x14  one record per address space,
                                       from 0
    +0x488  xpd_$debuggers  6 * 0x10   the debugger slots, from 1

  The routines live in fragment files (xpd/<name>.pas), included below
  in image order.

  Build: dpc -I domain_os domain_os/xpd/xpd.pas.  Check:
  tools/pascal_check.sh.
}
module xpd;

{ TODO(pascal) the two 4-byte data blocks and the A5 loads into them

  XPD's two zero 4-byte data segments hold no object this module can
  name, and ten routines load A5 with their ends without using it; the
  nine .TEXT ones share no trait the others lack.  Until the cause is
  known the module declares nothing for them, and dpc loads no A5 here. }

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'proc2/proc2_data.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'mst/mst.ins.pas';
%include 'acl/acl.ins.pas';
%include 'peb/peb.ins.pas';
%include 'xpd/xpd.ins.pas';

{ The overlay section XPD_$DATA (above), in the order of its offsets. }
var (xpd_$data)
  xpd_$targets: array[0..57] of xpd_$target_t;         { +0x000 }
  xpd_$debuggers: array[1..6] of xpd_$debugger_t;      { +0x488 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  xpd_$init;
  xpd_$find_index;
  xpd_$set_ptrace_opts;
  xpd_$inq_ptrace_opts;
  xpd_$reset_ptrace_opts;
  xpd_$inherit_ptrace_options;
  xpd_$capture_fault;
  xpd_$restart;
  xpd_$read_proc_async;
  xpd_$read_proc;
  xpd_$write_proc;
  xpd_$read;
  xpd_$write;
  xpd_$set_debugger;
  xpd_$get_ec;
  xpd_$get_event_and_data;
  xpd_$continue_proc;
  xpd_$set_enable;
  xpd_$get_fp;
  xpd_$put_fp;
  xpd_$get_target_info;
  xpd_$cleanup;
  xpd_$post_event;

{ xpd_$unregister_debugger, module-local, in PROC2_DELETE_PRO:
  XPD_$SET_DEBUGGER calls it before its body. }
{ body: xpd/unregister_debugger.pas }
procedure xpd_$unregister_debugger(asid: integer; out status_ret: status_$t);
  forward; internal;

{ ---- OS_INIT_PROC ---- }
%include 'xpd/init.pas';                    { XPD_$INIT          }

{ ---- .TEXT ---- }
%include 'xpd/find_index.pas';              { XPD_$FIND_INDEX    }
%include 'xpd/set_ptrace_opts.pas';         { XPD_$SET_PTRACE_OPTS }
%include 'xpd/inq_ptrace_opts.pas';         { XPD_$INQ_PTRACE_OPTS }
%include 'xpd/reset_ptrace_opts.pas';       { XPD_$RESET_PTRACE_OPTS }
%include 'xpd/inherit_ptrace_options.pas';  { XPD_$INHERIT_PTRACE_OPTIONS }
%include 'xpd/capture_fault.pas';           { XPD_$CAPTURE_FAULT, its
                                              nested xpd_$exec_event }
%include 'xpd/restart.pas';                 { XPD_$RESTART       }
%include 'xpd/copy_memory.pas';             { xpd_$copy_memory }
%include 'xpd/read_proc_async.pas';         { XPD_$READ_PROC_ASYNC }
%include 'xpd/read_proc.pas';               { XPD_$READ_PROC }
%include 'xpd/write_proc.pas';              { XPD_$WRITE_PROC }
%include 'xpd/read.pas';                    { XPD_$READ }
%include 'xpd/write.pas';                   { XPD_$WRITE }
%include 'xpd/find_debugger_index.pas';     { xpd_$find_debugger_index }
%include 'xpd/register_debugger.pas';       { XPD_$REGISTER_DEBUGGER }
%include 'xpd/set_debugger.pas';            { XPD_$SET_DEBUGGER }
%include 'xpd/get_ec.pas';                  { XPD_$GET_EC }
%include 'xpd/get_event_and_data.pas';      { XPD_$GET_EVENT_AND_DATA }
%include 'xpd/continue_proc.pas';           { XPD_$CONTINUE_PROC }
%include 'xpd/set_enable.pas';              { XPD_$SET_ENABLE }
%include 'xpd/get_fp.pas';                  { XPD_$GET_FP }
%include 'xpd/put_fp.pas';                  { XPD_$PUT_FP }
%include 'xpd/get_target_info.pas';         { XPD_$GET_TARGET_INFO }

{ ---- PROC2_DELETE_PRO ---- }
%include 'xpd/unregister_debugger.pas';     { xpd_$unregister_debugger }
%include 'xpd/cleanup.pas';                 { XPD_$CLEANUP }
%include 'xpd/post_event.pas';              { XPD_$POST_EVENT }
