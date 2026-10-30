{ net/net.pas - the NET module, the network device abstraction layer.

  One compilation unit, one code segment, no data.  The map's NET code
  segment (section .TEXT, 0x274 bytes) holds the six NET_ map symbols,
  NET_$GET_INFO .. NET_$SEND, after the module-local net_$find_handler,
  with which the segment starts and which the five dispatchers call.
  All seven are compiler output; none loads A5, the module has no data
  segment, and the heading names no sections (.TEXT, the default).

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/net/net.pas.  Check: tools/pascal_check.sh.
}
module net;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';               { for net_io and route (NET_IO) }
%include 'pkt/pkt.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'route/route.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'net/net.ins.pas';

{ The global routines this module defines (ref 7.3.4), in map order. }
define
  net_$get_info;
  net_$open;
  net_$close;
  net_$ioctl;
  net_$rcv;
  net_$send;

{ ---- .TEXT ---- }
%include 'net/find_handler.pas';            { net_$find_handler }
%include 'net/get_info.pas';                { NET_$GET_INFO     }
%include 'net/open.pas';                    { NET_$OPEN         }
%include 'net/close.pas';                   { NET_$CLOSE        }
%include 'net/ioctl.pas';                   { NET_$IOCTL        }
%include 'net/rcv.pas';                     { NET_$RCV          }
%include 'net/send.pas';                    { NET_$SEND         }
