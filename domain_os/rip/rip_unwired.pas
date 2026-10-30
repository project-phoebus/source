{ rip/rip_unwired.pas - the RIP_UNWIRED module: RIP's server, its
  updates, the routing table's read and write calls, the route updates
  by port and the name server announcement.

  One compilation unit, in the default sections: the map's RIP_UNWIRED
  code segment in .TEXT (0x958 bytes, RIP_$SEND_UPDATES ..
  RIP_$ANNOUNCE_NS).

  There is no RIP_UNWIRED data segment (none in .DATA, DATA$ or another
  section), and no routine of the segment loads A5: RIP's data are
  RIP_WIRED's block, reached at its map symbols' addresses, another
  unit's variables.  So `module rip_unwired;'
  with no data of its own (rip/README.md).

  The routines, in image order: the module-local rip_$packet_length
  (`internal', no map symbol), RIP_$SEND_UPDATES, RIP_$SERVER with its
  nested rip_$process_request before it (rip/server.pas), RIP_$TABLE_D,
  RIP_$TABLE (rip/table.pas), RIP_$UPDATE_D, RIP_$UPDATE
  (rip/update.pas), RIP_$ANNOUNCE_NS (rip/announce_ns.pas).  None is
  hand assembly.

  The constant cells: RIP_$SERVER's two after its
  code, TIME_$WAIT's time_$relative and PKT_$SEND_INTERNET's data, the
  integer32 0 (named again by RIP_$ANNOUNCE_NS); RIP_$TABLE's one,
  RIP_$TABLE_D's route type, false.  The segment ends at
  RIP_$ANNOUNCE_NS's return, on a multiple of 4: no padding.

  Loop alignment: aligning code (fillers before the loop heads;
  RIP_$SERVER has two more before joins that are no loop heads).

  Build: dpc -I domain_os domain_os/rip/rip_unwired.pas.  Check:
  tools/pascal_check.sh.
}

module rip_unwired;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net/net.ins.pas';
%include 'xns/xns.ins.pas';
%include 'rip/rip.ins.pas';
%include 'network/network.ins.pas';
%include 'uid/uid.ins.pas';
%include 'hint/hint.ins.pas';
%include 'rem_name/rem_name.ins.pas';

{ The globals this module defines (ref 7.3.4, Method 2), in map order. }
define
  rip_$send_updates;
  rip_$server;
  rip_$table_d;
  rip_$table;
  rip_$update_d;
  rip_$update;
  rip_$announce_ns;

{ ---- .TEXT ---- }
%include 'rip/packet_length.pas';         { rip_$packet_length }
%include 'rip/send_updates.pas';          { RIP_$SEND_UPDATES }
%include 'rip/server.pas';                { RIP_$SERVER and its nested
                                            routine }
%include 'rip/table_d.pas';               { RIP_$TABLE_D }
%include 'rip/table.pas';                 { RIP_$TABLE }
%include 'rip/update_d.pas';              { RIP_$UPDATE_D }
%include 'rip/update.pas';                { RIP_$UPDATE }
%include 'rip/announce_ns.pas';           { RIP_$ANNOUNCE_NS }
