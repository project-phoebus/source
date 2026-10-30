{ cal/os_cal_unwired.pas - the OS_CAL_UNWIRED module: the calendar's check
  at boot, the timezone getters and setters, the local-time offsets and
  the date conversions.

  One compilation unit, in the default code section, with no data of its
  own: the map's OS_CAL_UNWIRED code segment in .TEXT (0x4E4 bytes), the
  eight routines in the order of the `define' list below.

  The routines reach CAL_$TIMEZONE and CAL_$LAST_VALID_TIME,
  OS_CAL_WIRED's module variables (cal/os_cal_wired.pas), by their
  absolute addresses and never load A5.  So `module os_cal_unwired;'
  with no variables, in a unit of its own, as the map names it.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/cal/os_cal_unwired.pas.  Check: tools/pascal_check.sh.
}
module os_cal_unwired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'suma/suma.ins.pas';
%include 'term/term.ins.pas';
%include 'cal/cal.ins.pas';

define
  cal_$verify;
  cal_$get_info;
  cal_$set_drift;
  cal_$get_local_time;
  cal_$apply_local_offset;
  cal_$remove_local_offset;
  cal_$weekday;
  cal_$decode_time;

{ ---- .TEXT ---- }
%include 'cal/verify.pas';                  { CAL_$VERIFY              }
%include 'cal/get_info.pas';                { CAL_$GET_INFO            }
%include 'cal/set_drift.pas';               { CAL_$SET_DRIFT           }
%include 'cal/get_local_time.pas';          { CAL_$GET_LOCAL_TIME      }
%include 'cal/apply_local_offset.pas';      { CAL_$APPLY_LOCAL_OFFSET  }
%include 'cal/remove_local_offset.pas';     { CAL_$REMOVE_LOCAL_OFFSET }
%include 'cal/weekday.pas';                 { CAL_$WEEKDAY             }
%include 'cal/decode_time.pas';             { CAL_$DECODE_TIME         }
