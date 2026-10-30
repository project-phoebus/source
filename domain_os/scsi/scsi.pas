{ scsi/scsi.pas - the SCSI_ module, the SCSI driver.

  Image addresses:
    sau2  0x00E88804  SCSI_ data (SCSI_WIRED_DATA, 0x4 bytes)
    sau9  0x3C4A7240  SCSI_ data (SCSI_WIRED_DATA, 0x374 bytes)
    sau9  0x3C43CF9C  SCSI_ data (OS_INIT_DATA, 0x4 bytes)

  Configured out on the SAU2: the map's SCSI_ code segments in
  OS_INIT_PROC (0x10 bytes, SCSI_$CINIT) and SCSI_WIRED_PROC (4 bytes,
  SCSI_$FREE_ASID), and its data segment in SCSI_WIRED_DATA (4 bytes,
  SCSI_$PRESENT, a module variable).

  With the driver (`scsi_driver', base/config.ins.pas), on the SAU9: the
  driver of the NCR 53C90 controller.  The map's SCSI_ code segment in
  OS_INIT_PROC (0x408 bytes: SCSI_$INIT, SCSI_$CINIT and a module-local
  routine), SCSI_WIRED_PROC (0x2640 bytes: 26 module-local routines and
  SCSI_$ABORT_OPERATION .. SCSI_$DO_SYS_DEVICE_CMD), its data segment in
  SCSI_WIRED_DATA (0x374 bytes) and a 4-byte block in OS_INIT_DATA (zero,
  never addressed; the OS_INIT_PROC routines' A5 is its end).  The
  SCSI_ASM segments, SCSI_$HP_WRITE and SCSI_$HP_READ, are hand assembly
  (scsi/sau9/scsi_asm.s).  See the TODO(sau) below.

  The heading names SCSI_WIRED_PROC and SCSI_WIRED_DATA (the LOG
  shape); the OS_INIT_PROC routines are headed `[section(os_init_proc,
  os_init_data)]' and reach the block by its address.

  The data block (SCSI_WIRED_DATA), zero except the values given:

    +0x000  scsi_null_cdb        the command block of a device reset
    +0x00C  unused_00c           4 bytes nothing addresses (a stand-in)
    +0x010  scsi_$cb             the bus (one), 800 bytes: its window
                                 16#3FF9F400, its current target 7, its
                                 never_selected true
    +0x330  scsi_wired_pages     the module's wired pages, 11
    +0x35C  scsi_lock            ML_$SPIN_LOCK's lock
    +0x360  scsi_$spurious_ints
    +0x364  scsi_bus_count       the buses (SCSI_$INIT: 1)
    +0x366  scsi_init_count      the buses set up
    +0x368  scsi_cnts
    +0x36A  scsi_open_count      the devices set up
    +0x36C  scsi_wired_count     the module's wired pages' count
    +0x36E  scsi_wired           the module's pages are wired
    +0x370  scsi_$present
    +0x371  (3 bytes of rounding)

  The routines live in one fragment file each (scsi/<name>.pas), in
  image order within each section.

  Check: tools/pascal_check.sh.
}
module scsi_, scsi_wired_proc, scsi_wired_data;

%include 'base/base.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%if scsi_driver %then
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'parity/parity.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'fim/fim.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'as/as.ins.pas';
%include 'sysbus/sysbus.ins.pas';
%include 'os/os.ins.pas';
%endif
%include 'scsi/scsi.ins.pas';
%if scsi_driver %then
%include 'scsi/scsi_c90.ins.pas';

{ TODO(sau) the SAU7 SCSI code

  The module's code below is the SAU9's, the 53C90 driver.  The SAU7's
  SCSI_ module (code 0x1CA8 bytes in SCSI_WIRED_PROC, 0x6B8 bytes of
  data) drives another controller (the map's SCSI_MAILBOXES and
  SCSI_SCBS regions, SCSI_$INT and SCSI_$TINFO_LIST): tools/sau_catalog.py
  finds every routine the two share different.  The SAU7 needs its own
  part and form when it is translated. }
%endif

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the data block (above). }
define
  scsi_$cinit;
  scsi_$free_asid;
%if scsi_driver %then
  scsi_$init;
  scsi_$abort_operation;
  scsi_$do_command_phys;
  scsi_$do_command;
  scsi_$set_sys_device;
  scsi_$get_ec;
  scsi_$get_info;
  scsi_$c90_int;
  scsi_$c90_dma;
  scsi_$release;
  scsi_$reset_device;
  scsi_$setup;
  scsi_$unwire;
  scsi_$wait;
  scsi_$wire;
  scsi_$do_sys_device_cmd;
var
  scsi_null_cdb: scsi_$cdb_t;                   { +0x000 }
  unused_00c: integer32;                        { +0x00C: stand-in }
define
  scsi_$cb := [[                                { +0x010 }
    regs := c90_regs_ptr_t(16#3FF9F400),
    cur_target := scsi_host_id,
    never_selected := true]];
var
  scsi_wired_pages: array[1..11] of integer32;  { +0x330 }
  scsi_lock: integer32;                         { +0x35C }
define
  scsi_$spurious_ints;                          { +0x360 }
var
  scsi_bus_count: integer;                      { +0x364 }
  scsi_init_count: integer;                     { +0x366 }
define
  scsi_cnts;                                    { +0x368 }
var
  scsi_open_count: integer;                     { +0x36A }
  scsi_wired_count: integer;                    { +0x36C }
  scsi_wired: boolean;                          { +0x36E }
%endif
define
  scsi_$present;                                { +0x370 }

%if scsi_driver %then
{ The module-local routines called before their bodies. }
{ body: scsi/init_ppn_owners.pas }
procedure scsi_init_ppn_owners; forward; internal;
{ body: scsi/msg_in.pas }
procedure scsi_msg_in(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                      req: scsi_req_ptr_t; in msg: univ scsi_msg_buf_t;
                      count: integer);
  forward; internal;
{ body: scsi/phase_dispatch.pas }
procedure scsi_phase_dispatch(cb: scsi_cb_ptr_t; tgt: scsi_target_ptr_t;
                              req: scsi_req_ptr_t; phase: integer);
  forward; internal;
{ body: scsi/enable_select.pas }
procedure scsi_enable_select(cb: scsi_cb_ptr_t); forward; internal;
{ body: scsi/finish_data.pas }
procedure scsi_finish_data(cb: scsi_cb_ptr_t; req: scsi_req_ptr_t);
  forward; internal;
{ body: scsi/unwire_all.pas }
procedure scsi_unwire_all(dev: integer); forward; internal;
{ body: scsi/complete_req.pas }
procedure scsi_complete_req(tgt: scsi_target_ptr_t); forward; internal;
{ body: scsi/start_next.pas }
procedure scsi_start_next(cb: scsi_cb_ptr_t); forward; internal;
%endif

{ ---- OS_INIT_PROC ---- }
%if scsi_driver %then
%include 'scsi/init.pas';                   { SCSI_$INIT         }
%endif
%include 'scsi/cinit.pas';                  { SCSI_$CINIT        }
%if scsi_driver %then
%include 'scsi/init_ppn_owners.pas';        { scsi_init_ppn_owners }
%endif

{ ---- SCSI_WIRED_PROC ---- }
%if scsi_driver %then
%include 'scsi/find_req.pas';               { scsi_find_req (at the map's
                                              SCSI_$PROC_START) }
%include 'scsi/free_req.pas';               { scsi_free_req      }
%include 'scsi/remove_done_req.pas';        { scsi_remove_done_req }
%include 'scsi/get_req.pas';                { scsi_get_req       }
%include 'scsi/queue_req.pas';              { scsi_queue_req     }
%include 'scsi/va_to_ppn.pas';              { scsi_va_to_ppn     }
%include 'scsi/wire_driver.pas';            { scsi_wire_driver   }
%include 'scsi/unwire_driver.pas';          { scsi_unwire_driver }
%include 'scsi/abort_operation.pas';        { SCSI_$ABORT_OPERATION }
%include 'scsi/do_command_phys.pas';        { SCSI_$DO_COMMAND_PHYS }
%include 'scsi/do_command.pas';             { SCSI_$DO_COMMAND   }
%endif
%include 'scsi/free_asid.pas';              { SCSI_$FREE_ASID    }
%if scsi_driver %then
%include 'scsi/set_sys_device.pas';         { SCSI_$SET_SYS_DEVICE }
%include 'scsi/get_ec.pas';                 { SCSI_$GET_EC       }
%include 'scsi/get_info.pas';               { SCSI_$GET_INFO     }
%include 'scsi/c90_int.pas';                { SCSI_$C90_INT      }
%include 'scsi/msg_in.pas';                 { scsi_msg_in        }
%include 'scsi/msg_out.pas';                { scsi_msg_out       }
%include 'scsi/msg_in_start.pas';           { scsi_msg_in_start  }
%include 'scsi/status_start.pas';           { scsi_status_start  }
%include 'scsi/xfer_pad.pas';               { scsi_xfer_pad      }
%include 'scsi/start_dma.pas';              { scsi_start_dma     }
%include 'scsi/send_cdb.pas';               { scsi_send_cdb      }
%include 'scsi/phase_dispatch.pas';         { scsi_phase_dispatch }
%include 'scsi/c90_dma.pas';                { SCSI_$C90_DMA      }
%include 'scsi/enable_select.pas';          { scsi_enable_select }
%include 'scsi/finish_data.pas';            { scsi_finish_data   }
%include 'scsi/release.pas';                { SCSI_$RELEASE      }
%include 'scsi/reset_device.pas';           { SCSI_$RESET_DEVICE }
%include 'scsi/setup.pas';                  { SCSI_$SETUP        }
%include 'scsi/wire_page.pas';              { scsi_wire_page     }
%include 'scsi/unwire_page.pas';            { scsi_unwire_page   }
%include 'scsi/unwire_all.pas';             { scsi_unwire_all    }
%include 'scsi/unwire.pas';                 { SCSI_$UNWIRE       }
%include 'scsi/wait.pas';                   { SCSI_$WAIT         }
%include 'scsi/wire.pas';                   { SCSI_$WIRE         }
%include 'scsi/complete_req.pas';           { scsi_complete_req  }
%include 'scsi/start_cmd.pas';              { scsi_start_cmd     }
%include 'scsi/start_abort.pas';            { scsi_start_abort   }
%include 'scsi/start_next.pas';             { scsi_start_next    }
%include 'scsi/do_sys_device_cmd.pas';      { SCSI_$DO_SYS_DEVICE_CMD }
%endif
