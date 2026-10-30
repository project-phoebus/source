{ asknode/asknode.pas - the ASKNODE module, the node-information
  requester and server.

  Image addresses:
    sau2  0x00E82408  ASKNODE data (.DATA, 0x20 bytes)

  One compilation unit, in one code section and one data section: the
  map's ASKNODE code segment in .TEXT (0x21A0 bytes: the nine ASKNODE_
  routines and the module-local route_$validate_port,
  route/validate_port.pas) and its ASKNODE data segment in .DATA (0x20
  bytes).  The heading names no sections, `module asknode;'.

  The data, 0x20 bytes:
    +0x00  asknode_$pkt_info          30  the packet-info template every
                                          sender copies whole and passes
                                          to PKT_$SAR_ or _$SEND_INTERNET
    +0x1E  asknode_$protocol_version   2  integer, 3

  The copy is 30 bytes and the word is read on its own, so they are two
  objects (as REM_NAME's template), not one 32-byte pkt_$info_t.

  The routines live in one fragment file each (asknode/<name>.pas;
  route_$validate_port's in route/), included below in image order; the
  headings of asknode/asknode.ins.pas and asknode/asknode_info.ins.pas
  come first.

  Build: dpc -I domain_os domain_os/asknode/asknode.pas.  Check:
  tools/pascal_check.sh.
}
module asknode;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'io/io.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'node/node.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'mst/mst.ins.pas';
%include 'peb/peb.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'fim/fim.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'xns/xns.ins.pas';
%include 'app/app.ins.pas';
%include 'rip/rip.ins.pas';
%include 'ring/ring.ins.pas';
%include 'ring/ringlog.ins.pas';
%include 'asknode/asknode.ins.pas';
%include 'log/log.ins.pas';
%include 'hint/hint.ins.pas';
%include 'cal/cal.ins.pas';
%include 'volx/volx.ins.pas';
%include 'disk/disk.ins.pas';
%include 'smd/smd.ins.pas';
%include 'misc/misc.ins.pas';
%include 'os/os.ins.pas';
%include 'name/name.ins.pas';
%include 'mem/mem.ins.pas';
%include 'dir/dir.ins.pas';
%include 'gpu/gpu.ins.pas';
%include 'prom/prom.ins.pas';
%include 'net/net.ins.pas';
%include 'asknode/asknode_info.ins.pas';

type
  { The packet-info template, 30 bytes: pkt/pkt.ins.pas pkt_$info_t's
    first 30 bytes, its names, offsets and types (rip/rip.ins.pas
    rip_$template_t and REM_NAME's template are the same 30 bytes).  The
    senders write its words in their copies: SERVER the flags and
    retry_limit, PROPAGATE_WHO addr_type and protocol as one longword. }
  asknode_$template_t = record
    flags: pinteger;                      { 0x00 }
    routing_type: integer;                { 0x02 }
    addr_type: integer;                   { 0x04 }
    protocol: pinteger;                   { 0x06 }
    retry_limit: pinteger;                { 0x08 }
    field_0a: pinteger;                   { 0x0A }
    field_0c: pinteger;                   { 0x0C }
    addr: array[1..16] of char;           { 0x0E }
  end;

  { The who-request WHO_NOTOPO and WHO_REMOTE send, 0x18 bytes (the
    send's template length): ASKNODE_$SERVER's request_t
    (asknode/server.pas, its names) without the parameter-block view,
    which these two do not use.  WHO_NOTOPO writes the version and type
    as one longword, then the args' param1, param2 and param3 at +0x08,
    +0x0C and +0x14; WHO_REMOTE the version and type as words, the node
    at +0x04, and either the hop word at +0x08 or the args' param1,
    param2, forwarded, count and param3.  The bytes neither writes are
    what the frame held. }
  asknode_$who_request_t = record
    version: integer;                     { 0x00 }
    req_type: integer;                    { 0x02 }
    case integer of
      1: (args: asknode_$server_args_t);  { 0x04..0x17 }
      2: (unused_04: linteger;            { 0x04 }
          hops: integer);                 { 0x08 }
  end;

  { A who-reply, 0x200 bytes: ASKNODE_$SERVER's reply_t
    (asknode/server.pas, its names and offsets) without the log view.
    PROPAGATE_WHO sends one, the version and type as one longword and
    the status.  WHO_NOTOPO and WHO_REMOTE copy one in from the packet
    (up to 0x200 bytes) and read the status; WHO_REMOTE also the type
    (1 or 16#2E), the node (against NODE_$ME), the flags (compared with
    16#B1FF) and the count. }
  asknode_$who_reply_t = record
    version: pinteger;                    { 0x00 }
    response_type: pinteger;              { 0x02 }
    status: status_$t;                    { 0x04 }
    case integer of
      0: (raw: array[1..504] of char); { 0x08..0x1FF }
      1: (node: linteger;                 { 0x08 }
          flags: pinteger;                { 0x0C }
          count: integer);                { 0x0E }
  end;

{ The module's own variables (ref 7.2.2), in the order of the block
  (above), the routines in map order. }
var
  asknode_$pkt_info: asknode_$template_t :=
    [flags := 16#10, routing_type := pkt_$routing_inet,
     addr_type := pkt_$addr_long,
     protocol := 16#8031, retry_limit := 16#FFFF, field_0a := 0,
     field_0c := 16#FFFF];                         { +0x00 }
  asknode_$protocol_version: integer := 3;         { +0x1E }

define
  asknode_$info;
  asknode_$get_info;
  asknode_$internet_info;
  asknode_$read_failure_rec;
  asknode_$server;
  asknode_$propagate_who;
  asknode_$who;
  asknode_$who_notopo;
  asknode_$who_remote;

{ ---- .TEXT ---- }
%include 'asknode/info.pas';                 { ASKNODE_$INFO }
%include 'asknode/get_info.pas';             { ASKNODE_$GET_INFO }
%include 'asknode/internet_info.pas';        { ASKNODE_$INTERNET_INFO }
%include 'asknode/read_failure_rec.pas';     { ASKNODE_$READ_FAILURE_REC }
%include 'route/validate_port.pas';          { route_$validate_port }
%include 'asknode/server.pas';               { ASKNODE_$SERVER }
%include 'asknode/propagate_who.pas';        { ASKNODE_$PROPAGATE_WHO }
%include 'asknode/who.pas';                  { ASKNODE_$WHO }
%include 'asknode/who_notopo.pas';           { ASKNODE_$WHO_NOTOPO }
%include 'asknode/who_remote.pas';           { ASKNODE_$WHO_REMOTE }
