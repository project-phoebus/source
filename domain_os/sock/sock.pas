{ sock/sock.pas - the SOCK module, the network sockets.

  Image addresses:
    sau2  0x00E27510  SOCK data (WIRED_DATA, 0x1C28 bytes)

  One compilation unit, in two code sections and one data section: the
  map's SOCK code segments in WIRED_PROC (0x5B4 bytes, SOCK_$OPEN ..
  SOCK_$PUT_INT_INT) and in OS_INIT_PROC (0x7C bytes, SOCK_$INIT), and
  its SOCK data segment in WIRED_DATA (0x1C28 bytes).

  The heading names wired_proc and wired_data; SOCK_$INIT is headed
  `[section(os_init_proc, os_init_data)]' and reaches the block by its
  address (suma/suma.pas, dtty/dtty.pas the same).

  The data, 0x1C28 bytes, all zero in the image but the user limit:

    +0x0000  SOCK_LIST         0x20    the free list's head at +0x0C
                                       (sock_$list_t); defined here
    +0x0020  SOCK_$SOCKET      0x1880  sockets 1..224, 0x1C bytes each;
                                       defined here
    +0x18A0  sock_lock         4       the spin lock

    +0x18A4  SOCK_$SOCKET_PTR  0x380   the descriptors' pointers 1..224;
                                       defined here
    +0x1C24  sock_user_limit   2       the user sockets still allowed,
                                       64 in the image
    +0x1C26  2 bytes: the block's rounding to 4 (dtty/dtty.pas)

  The code indexes the arrays from 1 only: no socket 0 overlays
  SOCK_LIST's tail, and no pointer 0, nor 225, overlays the lock or the
  limit.

  Build: dpc -I domain_os domain_os/sock/sock.pas.  Check:
  tools/pascal_check.sh.
}
module sock, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'sock/sock.ins.pas';

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the block (above). }
define
  sock_$open;
  sock_$allocate;
  sock_$allocate_user;
  sock_$close;
  sock_$get;
  sock_$put;
  sock_$put_int;
  sock_$put_int_int;
  sock_$init;

define
  sock_list;                              { +0x0000 }
  sock_$socket;                           { +0x0020 }

var
  sock_lock: integer32;                   { +0x18A0 }

define
  sock_$socket_ptr;                       { +0x18A4 }

var
  sock_user_limit: integer := 16#40;      { +0x1C24 }

{ ---- WIRED_PROC ---- }
%include 'sock/open.pas';                   { SOCK_$OPEN          }
%include 'sock/allocate.pas';               { SOCK_$ALLOCATE      }
%include 'sock/allocate_user.pas';          { SOCK_$ALLOCATE_USER }
%include 'sock/close.pas';                  { SOCK_$CLOSE         }
%include 'sock/get.pas';                    { SOCK_$GET           }
%include 'sock/put.pas';                    { SOCK_$PUT }
%include 'sock/put_int.pas';                { SOCK_$PUT_INT }
%include 'sock/put_int_int.pas';            { SOCK_$PUT_INT_INT }

{ ---- OS_INIT_PROC ---- }
%include 'sock/init.pas';                   { SOCK_$INIT          }
