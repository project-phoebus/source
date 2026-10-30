{ misc/print_build_time_.pas - the PRINT_BUILD_TIME module: the kernel's
  banner and revision record.

  Image addresses:
    sau2  0x00E78400  PRINT_BUILD_TIME data (.DATA, 0xD0 bytes)

  One compilation unit in the default sections: the map's code segment
  in .TEXT (PRINT_BUILD_TIME, OS_$GET_REV_INFO, GET_BUILD_TIME) and its
  data segment in .DATA (208 bytes: OS_$REV, then BUILD_$TIME at
  +0xCC).  The file takes a trailing underscore: print_build_time.pas is
  PRINT_BUILD_TIME's fragment.

  The block's contents, as the `define' below gives them:
    +0x00  os_rev 0, major 10, minor 2, patch 0, build 0, the stamp
           16#46347587
    +0x10 .. +0x5F  zeros (reserved)
    +0x60  the name, date and time lengths: 16, 0, 29
    +0x6C  'Domain/OS kernel' and 16 blanks (name)

    +0x8C  32 blanks (date)
    +0xAC  'October 13, 1989  11:47:27 am' and 3 blanks (time)
    +0xCC  BUILD_$TIME, 16#46347587

  Build: dpc -I domain_os domain_os/misc/print_build_time_.pas.  Check:
  tools/pascal_check.sh.
}
module print_build_time;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'prom/prom.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'misc/misc.ins.pas';

{ The module's globals (ref 7.2.2, 7.3.4): the three routines and the
  two data objects, in map order, the data with the image's bytes. }
define
  print_build_time;
  os_$get_rev_info;
  get_build_time;
  os_$rev := [os_rev := 0, major := 10, minor := 2, patch := 0,
              build := 0, stamp := 16#46347587,
              name_len := 16, date_len := 0, time_len := 29,
              name := 'Domain/OS kernel                ',
              date := '                                ',
              time := 'October 13, 1989  11:47:27 am   '];
  build_$time := 16#46347587;

{ ---- .TEXT ---- }
%include 'misc/print_build_time.pas';     { PRINT_BUILD_TIME   }
%include 'os/get_rev_info.pas';           { OS_$GET_REV_INFO   }
%include 'misc/get_build_time.pas';       { GET_BUILD_TIME     }
