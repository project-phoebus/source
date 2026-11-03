{ netbuf/netbuf.pas - the NETBUF_ module, the network buffers.

  Image addresses:
    sau2  0x00E245A8  NETBUF_ data (WIRED_DATA, 0x338 bytes)
    sau8  0x03C26650  NETBUF_ data (WIRED_DATA, 0x338 bytes)
    sau9  0x3C427DA8  NETBUF_ data (WIRED_DATA, 0x338 bytes)

  One compilation unit: the map's NETBUF_ code segments in WIRED_PROC
  (0x85C bytes, netbuf_rtnva_locked and NETBUF_$ADD_PAGES ..
  NETBUF_$RTN_PKT) and OS_INIT_PROC (0x54 bytes, NETBUF_$INIT), and its
  data segment in WIRED_DATA (0x338 bytes).

  The heading: `module netbuf_, wired_proc, wired_data;'; NETBUF_$INIT
  is headed `[section(os_init_proc, os_init_data)]'.

  The data, 0x338 bytes, zero but netbuf_$delay_time's low word:

    +0x000  netbuf_$va_slots      192 * 4  a free slot holds the next
                                           free slot's number, a used
                                           one its page's physical address
    +0x300  netbuf_$delay_time    6        the GET routines' wait: high
                                           0, low 16#8000

    +0x306  (2 bytes: netbuf_$spin_lock's alignment)
    +0x308  netbuf_$spin_lock     4        the pools' lock

    +0x30C  NETBUF_$DAT_ALLOCS    4        defined; the counts of
    +0x310  NETBUF_$HDR_ALLOCS    4        defined;   allocations and
    +0x314  NETBUF_$DAT_DELAYS    4        defined;   delays
    +0x318  NETBUF_$HDR_DELAYS    4        defined

    +0x31C  NETBUF_$DAT_LIM       4        defined; the data pool's limit
    +0x320  NETBUF_$DAT_CNT       4        defined; the data pool's count
    +0x324  NETBUF_$DAT_TOP       4        defined; the first free data page
    +0x328  NETBUF_$HDR_TOP       4        defined; the first free header
                                           page's address

    +0x32C  netbuf_$va_top        4        the first free slot, -1 for none
    +0x330  netbuf_$va_base_addr  4        the window's address
    +0x334  NETBUF_HDR_ALLOC      2        defined; a word
    +0x336  (2 bytes: the block's rounding to 4)

  The routines live in one fragment file each (netbuf/<name>.pas),
  included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/netbuf/netbuf.pas.  Check: tools/pascal_check.sh.
}
module netbuf_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'wp/wp.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'netbuf/netbuf.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  netbuf_$va_slots: array[0..191] of integer32;    { +0x000, zero }
  netbuf_$delay_time: time_$clock_t :=
    [high := 0, low := 16#8000];                   { +0x300 }
  netbuf_$spin_lock: integer32;                    { +0x308, zero }

define
  netbuf_$dat_allocs;                              { +0x30C, zero }
  netbuf_$hdr_allocs;                              { +0x310 }
  netbuf_$dat_delays;                              { +0x314 }
  netbuf_$hdr_delays;                              { +0x318 }
  netbuf_$dat_lim;                                 { +0x31C }
  netbuf_$dat_cnt;                                 { +0x320 }
  netbuf_$dat_top;                                 { +0x324 }
  netbuf_$hdr_top;                                 { +0x328 }

var
  netbuf_$va_top: integer32;                       { +0x32C, zero }
  netbuf_$va_base_addr: integer32;                 { +0x330, zero }

define
  netbuf_hdr_alloc;                                { +0x334, zero }
  netbuf_$add_pages;
  netbuf_$del_pages;
  netbuf_$getva;
  netbuf_$rtnva;
  netbuf_$get_hdr_cond;
  netbuf_$get_hdr;
  netbuf_$rtn_hdr;
  netbuf_$get_dat_cond;
  netbuf_$get_dat;
  netbuf_$rtn_dat;
  netbuf_$rtn_pkt;
  netbuf_$init;

{ ---- WIRED_PROC ---- }
%include 'netbuf/rtnva_locked.pas';         { netbuf_rtnva_locked }
%include 'netbuf/add_pages.pas';            { NETBUF_$ADD_PAGES   }
%include 'netbuf/del_pages.pas';            { NETBUF_$DEL_PAGES   }
%include 'netbuf/getva.pas';                { NETBUF_$GETVA       }
%include 'netbuf/rtnva.pas';                { NETBUF_$RTNVA       }
%include 'netbuf/get_hdr_cond.pas';         { NETBUF_$GET_HDR_COND }
%include 'netbuf/get_hdr.pas';              { NETBUF_$GET_HDR }
%include 'netbuf/rtn_hdr.pas';              { NETBUF_$RTN_HDR     }
%include 'netbuf/get_dat_cond.pas';         { NETBUF_$GET_DAT_COND }
%include 'netbuf/get_dat.pas';              { NETBUF_$GET_DAT }
%include 'netbuf/rtn_dat.pas';              { NETBUF_$RTN_DAT     }
%include 'netbuf/rtn_pkt.pas';              { NETBUF_$RTN_PKT     }

{ ---- OS_INIT_PROC ---- }
%include 'netbuf/init.pas';                 { NETBUF_$INIT        }
