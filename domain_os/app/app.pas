{ app/app.pas - the APP module, the application protocol layer.

  Image addresses:
    sau2  0x00E1DC0C  APP data (WIRED_DATA, 0x74 bytes)

  One compilation unit, `module app, wired_proc, wired_data;': the map's
  APP code segment in WIRED_PROC (APP_$RECEIVE, APP_$DEMUX,
  APP_$STD_OPEN), the section's first module, and its data segment in
  WIRED_DATA (116 bytes), whose map symbol is APP_$STD_IDP_CHANNEL.

  The data, zero but the word 16#FFFF at +0x14, by offset from A5:
    +0x00  exclusion_lock        18 bytes
    +0x12  unknown_12            2 bytes, nothing addresses it
    +0x14  APP_$STD_IDP_CHANNEL  2 bytes (defined here)
    +0x16  unknown_16            2 bytes, nothing addresses it
    +0x18  temp_buffer           92 bytes, APP_$RECEIVE's

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/app/app.pas.  Check: tools/pascal_check.sh.
}
module app, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'ring/ring.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'xns/xns.ins.pas';
%include 'app/app.ins.pas';

{ The global routines and the variable this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the data block (above).  APP_$STD_IDP_CHANNEL's initial value
  is the image's 16#FFFF.  Where the defined variable goes among the
  module's own: see the TODO(pascal) in log/log.pas. }
define
  app_$receive;
  app_$demux;
  app_$std_open;

var
  exclusion_lock: ml_$exclusion_t;        { +0x00 }
  unknown_12: integer;                    { +0x12 }

define
  app_$std_idp_channel := 16#FFFF;        { +0x14 }

var
  unknown_16: integer;                    { +0x16 }
  temp_buffer: array[1..92] of char;      { +0x18 }

{ ---- WIRED_PROC ---- }
%include 'app/receive.pas';                 { APP_$RECEIVE }
%include 'app/demux.pas';                   { APP_$DEMUX }
%include 'app/std_open.pas';                { APP_$STD_OPEN }
