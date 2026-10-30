{ iic/iic.pas - the IIC module, the internet interface controller's
  entry points.

  One compilation unit, one code segment, no data.  The map's IIC code
  segment (section .TEXT, 0xA0 bytes) holds the nine IIC_ routines, in
  the order of the `define' list below, and the compiled module-end
  filler.  On the SAU2 all nine are stubs.

  No IIC data block: IIC_$NETWORK_UID is in the UID_LIST segment
  (another unit's data), and the map's IIC_AQWRD_PROC and IIC_AQWRD_DATA
  sections are empty, their four labels IIC_$DATA_START, _$PROC_START,
  _$PROC_END and _$DATA_END at one address.  No routine loads A5.  Every
  routine is global (map symbols), none nested.

  The whole module is ../domain-pascal/tests/conformance/iic.pas
  (byte-identical in `make conform'); iic/README.md lists the
  differences.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/iic/iic.pas.  Check: tools/pascal_check.sh.
}
module iic;

%include 'base/base.ins.pas';
%include 'iic/iic.ins.pas';

{ The global routines this module defines (ref 7.3.4), in map order. }
define
  iic_$init;
  iic_$acquire;
  iic_$release;
  iic_$statistics;
  iic_$self_test;
  iic_$send;
  iic_$exists;
  iic_$receive;
  iic_$receive_check;

{ ---- .TEXT ---- }
%include 'iic/init.pas';                    { IIC_$INIT          }
%include 'iic/acquire.pas';                 { IIC_$ACQUIRE       }
%include 'iic/release.pas';                 { IIC_$RELEASE       }
%include 'iic/statistics.pas';              { IIC_$STATISTICS    }
%include 'iic/self_test.pas';               { IIC_$SELF_TEST     }
%include 'iic/send.pas';                    { IIC_$SEND          }
%include 'iic/exists.pas';                  { IIC_$EXISTS        }
%include 'iic/receive.pas';                 { IIC_$RECEIVE       }
%include 'iic/receive_check.pas';           { IIC_$RECEIVE_CHECK }
