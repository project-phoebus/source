{ cal/os_cal_wired.pas - the OS_CAL_WIRED module: the calendar's timezone
  record and the boot volume label's time fields.

  Image addresses:
    sau2  0x00E7B030  OS_CAL_WIRED data (.DATA, 0x14 bytes)

  One compilation unit, in the default sections: the map's OS_CAL_WIRED
  code segment in .TEXT (0x224 bytes: CAL_$READ_TIMEZONE,
  CAL_$WRITE_TIMEZONE, CAL_$SHUTDOWN) and its data segment in .DATA
  (0x14 bytes: CAL_$TIMEZONE, CAL_$LAST_VALID_TIME, CAL_$BOOT_VOLX).

  The segments are the last of the OS_DISK run of .TEXT and .DATA, the
  run the module's name calls wired; the heading names no sections.
  The calendar's other compiled routines are OS_CAL_UNWIRED
  (cal/os_cal_unwired.pas), its hand assembly OS_CAL_ASM
  (cal/README.md).

  The block's three objects are map symbols, defined here and declared
  `extern' in cal/cal.ins.pas (ref 7.2.2, 7.3.4, Method 2).

  The data, 0x14 bytes, all zero in the image:
    +0x00  CAL_$TIMEZONE         12  cal_$timezone_rec_t (utc_delta,
                                     tz_name, drift)
    +0x0C  CAL_$LAST_VALID_TIME   4  time_$clockh_t
    +0x10  CAL_$BOOT_VOLX         2  integer (OS_$INIT stores 1)
    +0x12  (2 bytes: the block's rounding to 4)

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/cal/os_cal_wired.pas.  Check: tools/pascal_check.sh.
}
module os_cal_wired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'node/node.ins.pas';
%include 'uid/uid.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'bat/bat.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'cal/cal.ins.pas';

{ The globals it defines (ref 7.2.2, 7.3.4, Method 2), in the order of
  the block (above), and the routines in map order. }
define
  cal_$timezone;                                   { +0x00, zero }
  cal_$last_valid_time;                            { +0x0C, zero }
  cal_$boot_volx;                                  { +0x10, zero }
  cal_$read_timezone;
  cal_$write_timezone;
  cal_$shutdown;

{ ---- .TEXT ---- }
%include 'cal/read_timezone.pas';           { CAL_$READ_TIMEZONE  }
%include 'cal/write_timezone.pas';          { CAL_$WRITE_TIMEZONE }
%include 'cal/shutdown.pas';                { CAL_$SHUTDOWN       }
