{ log/log.pas - the LOG_ module, the system error log.

  Image addresses:
    sau2  0x00E2B280  LOG_ data (WIRED_DATA, 0x1C bytes)
    sau4  0x0F82D934  LOG_ data (WIRED_DATA, 0x1C bytes)

  One compilation unit, `module log_, wired_proc, wired_data;': the
  map's LOG_ code segments in WIRED_PROC and OS_INIT_PROC (LOG_$INIT,
  headed `[section(os_init_proc, os_init_data)]') and its data segment
  in WIRED_DATA (28 bytes), which LOG_$INIT reaches by its address.

  The data, all zero in the image:
    +0x00  log_$logfile_uid      8 bytes (defined)
    +0x08  current_entry_ptr     4 bytes
    +0x0C  spin_lock             4 bytes, ML_$SPIN_LOCK's lock
    +0x10  wired_handle          4 bytes, MST_$WIRE's result

    +0x14  log_$logfile_ptr      4 bytes (defined)
    +0x18  dirty_flag            1 byte
    +0x19  (3 bytes of rounding)

  The defined variables are declared extern in log.ins.pas and defined
  here (ref 7.2.2, Method 2), in the block's order.

  The routines live in one fragment file each (log/<name>.pas), in image
  order within each section.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/log/log.pas.  Check: tools/pascal_check.sh.
}
module log_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'log/log.ins.pas';

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the data block (above). }

{ TODO(pascal) where a defined extern variable is allocated is undocumented

  The allocation of a defined extern variable relative to the module's
  own variables is not documented; the layout is the image's either way. }

define
  log_$logfile_uid;                       { +0x00 }
  log_$shutdn;
  log_$update;
  log_$add;
  log_$read;
  log_$read2;
  log_$init;

var
  current_entry_ptr: log_$entry_ptr_t;    { +0x08 }
  spin_lock: integer32;                   { +0x0C }
  wired_handle: integer32;                { +0x10 }

define
  log_$logfile_ptr;                       { +0x14 }

var
  dirty_flag: boolean;                    { +0x18 }

var
  { The two records at the start of the image, which survive a reboot.
    Not this module's data: the map's CRASH_RECORD segment (0xC bytes),
    CRASH_$RECORD, and LOG_$LAST_ENTRY after it.  Both are reached by
    their absolute addresses: another unit's variables. }
  crash_$record: extern crash_$record_t;
  log_$last_entry: extern log_$last_entry_t;

{ ---- WIRED_PROC ---- }
%include 'log/shutdn.pas';                  { LOG_$SHUTDN        }
%include 'log/update.pas';                  { LOG_$UPDATE        }
%include 'log/add.pas';                     { LOG_$ADD           }
%include 'log/read_internal.pas';           { log_$read_internal }
%include 'log/read.pas';                    { LOG_$READ          }
%include 'log/read2.pas';                   { LOG_$READ2         }

{ ---- OS_INIT_PROC ---- }
%include 'log/init.pas';                    { LOG_$INIT, nested
                                              log_$check_op_status }
