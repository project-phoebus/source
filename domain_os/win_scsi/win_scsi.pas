{ win_scsi/win_scsi.pas - the WIN_SCSI_ module, the SCSI Winchester disk
  driver.

  Image addresses:
    sau9  0x3C42F084  WIN_SCSI_ data (WIRED_DATA, 0xD68 bytes)

  One compilation unit, `module win_scsi_, wired_proc, wired_data;': the
  map's WIN_SCSI_ code segments in WIRED_PROC (0x18BC bytes: seven
  module-local routines, then WIN_SCSI_$DINIT .. WIN_SCSI_$DO_SYS_COMMAND)
  and OS_INIT_PROC (0x278 bytes: WIN_SCSI_$CINIT, headed
  `[section(os_init_proc, os_init_data)]', which reaches the block by its
  address), and its data segment in WIRED_DATA (3432 bytes).

  Present on the SAUs whose map has the module, the part win_scsi_disk
  (base/config.ins.pas: the SAU9), empty elsewhere.  The driver sends its
  commands through the SCSI_ driver (scsi/); WIN_SCSI_DCTE_0..7, its
  DCTEs, lie in the DCTES section (io/dctes.pas).

  The block, zero but for the jump table and the log index:

    +0x000  win_scsi_units        the nine units, 0x160 bytes each
    +0xC60  win_scsi_pages        a transfer's physical page addresses
    +0xCE0  win_scsi_log          the last ten sense answers
    +0xD44  unused_d44            4 bytes nothing addresses (a stand-in)
    +0xD48  win_scsi_jump_table   the table DISK_$REGISTER is given:
                                  SPIN_DOWN, SHUTDOWN, DINIT, none,
                                  DO_IO, ERROR_QUE, GET_STATS
    +0xD64  win_scsi_log_index    the next log entry, 1..10 (1)
    +0xD66  (2 bytes of rounding)

  Check: tools/pascal_check.sh.
}
module win_scsi_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%include 'time/time.ins.pas';
%include 'disk/disk.ins.pas';
%include 'scsi/scsi.ins.pas';

%if win_scsi_disk %then
%include 'win_scsi/win_scsi.ins.pas';

var
  win_scsi_units: array[0..win_scsi_max_ctlr] of win_scsi_unit_t;
                                          { +0x000 }
  win_scsi_pages: scsi_$phys_list_t;      { +0xC60 }
  win_scsi_log: array[1..10] of win_scsi_log_entry_t;
                                          { +0xCE0 }
  unused_d44: integer32;                  { +0xD44: stand-in }
  win_scsi_jump_table: array[0..6] of univ_ptr :=
    [addr(win_scsi_$spin_down), addr(win_scsi_$shutdown),
     addr(win_scsi_$dinit), nil, addr(win_scsi_$do_io),
     addr(win_scsi_$error_que), addr(win_scsi_$get_stats)];
                                          { +0xD48 }
  win_scsi_log_index: integer := 1;       { +0xD64 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  win_scsi_$dinit;
  win_scsi_$do_io;
  win_scsi_$error_que;
  win_scsi_$get_stats;
  win_scsi_$shutdown;
  win_scsi_$spin_down;
  win_scsi_$do_sys_command;
  win_scsi_$cinit;

{ ---- WIRED_PROC ---- }
%include 'win_scsi/request_sense.pas';     { win_scsi_request_sense    }
%include 'win_scsi/check_result.pas';      { win_scsi_check_result     }
%include 'win_scsi/command.pas';           { win_scsi_command          }
%include 'win_scsi/command_phys.pas';      { win_scsi_command_phys     }
%include 'win_scsi/rw_block.pas';          { win_scsi_rw_block         }
%include 'win_scsi/set_error_page.pas';    { win_scsi_set_error_page   }
%include 'win_scsi/check_error_page.pas';  { win_scsi_check_error_page }
%include 'win_scsi/dinit.pas';             { WIN_SCSI_$DINIT           }
%include 'win_scsi/do_io.pas';             { WIN_SCSI_$DO_IO           }
%include 'win_scsi/error_que.pas';         { WIN_SCSI_$ERROR_QUE       }
%include 'win_scsi/get_stats.pas';         { WIN_SCSI_$GET_STATS       }
%include 'win_scsi/shutdown.pas';          { WIN_SCSI_$SHUTDOWN        }
%include 'win_scsi/spin_down.pas';         { WIN_SCSI_$SPIN_DOWN       }
%include 'win_scsi/do_sys_command.pas';    { WIN_SCSI_$DO_SYS_COMMAND  }

{ ---- OS_INIT_PROC ---- }
%include 'win_scsi/cinit.pas';             { WIN_SCSI_$CINIT           }

%endif
