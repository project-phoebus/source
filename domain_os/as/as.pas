{ as/as.pas - the AS module, the address-space layout.

  One compilation unit, two code segments, no data of its own: the map's
  AS code segments in OS_INIT_PROC (0x5C bytes, AS_$INIT) and in .TEXT
  (0xE8 bytes, AS_$GET_INFO and AS_$GET_ADDR).

  The data the routines read, AS_$INFO and AS_$INFO_SIZE, lie in the
  map's AS_ASM data segment (WIRED_DATA, 0x64 bytes), a hand-written
  block, so they are extern variables of as/as.ins.pas.  The block's
  initial values are the 68010 layout, which AS_$INIT changes on a
  68020.

  The heading names no sections: the module has no variables, and the
  .TEXT routines take the defaults; AS_$INIT is headed
  `[section(os_init_proc, os_init_data)]'.

  Build: dpc -I domain_os domain_os/as/as.pas.  Check:
  tools/pascal_check.sh.
}
module as;

%include 'base/base.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mst/mst.ins.pas';
%include 'as/as.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
%if pft_mmu or run_time_layout %then
  as_$init;
%endif
  as_$get_info;
  as_$get_addr;

{ ---- OS_INIT_PROC ---- }
{ AS_$INIT only on the SAUs whose OS_$INIT calls it (`pft_mmu',
  `run_time_layout', base/config.ins.pas): the SAU9's map has none. }
%if pft_mmu or run_time_layout %then
%include 'as/init.pas';                     { AS_$INIT     }
%endif

{ ---- .TEXT ---- }
%include 'as/get_info.pas';                 { AS_$GET_INFO }
%include 'as/get_addr.pas';                 { AS_$GET_ADDR }
