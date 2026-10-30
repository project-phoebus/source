{ mac/mac.ins.pas - MAC_ (the MAC layer's user interface), for the Domain
  Pascal tree.

  The status codes, the caller's records and the headings of the six
  MAC_ routines, routines of the MAC_OS module (mac/README.md).
  Include base/base.ins.pas, ec/ec.ins.pas, pkt/pkt.ins.pas,
  rip/rip.ins.pas and mac_os/mac_os.ins.pas before it.
}

const
  { MAC's status codes, the texts of
    stcode.db.10.2 (subsystem 0x3A), each stored by the routine given. }
  status_$mac_invalid_packet_type = 16#003A0004;    { "invalid packet
                                                      type"; MAC_$OPEN }
  status_$mac_no_os_sockets_available = 16#003A0006; { "no OS sockets
                                                      available"; MAC_$OPEN }
  status_$mac_channel_not_open = 16#003A0008;       { "channel is not
                                                      open"; MAC_$CLOSE,
                                                      _SEND, _RECEIVE }
  status_$mac_no_socket_allocated = 16#003A0009;    { "no socket allocated
                                                      for caller"; MAC_$OPEN,
                                                      _RECEIVE }
  status_$mac_no_packet_available_to_receive = 16#003A000A;
                                                    { "no packet available
                                                      to receive";
                                                      MAC_$RECEIVE }
  status_$mac_received_packet_too_big = 16#003A000B; { "data capacity too
                                                      small for received
                                                      packet"; MAC_$RECEIVE }
  status_$mac_failed_to_put_packet_into_socket = 16#003A0010;
                                                    { "could not put packet
                                                      into socket";
                                                      MAC_$DEMUX }
  status_$mac_invalid_port = 16#003A0011;           { "invalid port
                                                      number"; MAC_$OPEN }
  status_$mac_invalid_packet_type_count = 16#003A0012;
                                                    { "invalid type count";
                                                      MAC_$OPEN }

  { The bounds: the channels (compared unsigned by MAC_$CLOSE, MAC_$SEND,
    MAC_$RECEIVE), the packet types and the last port (MAC_$OPEN). }
  mac_max_channels = 10;
  mac_max_packet_types = 10;
  mac_max_port = 7;

  { The socket buffer size MAC_$OPEN asks SOCK_$ALLOCATE_USER for
    (sock/sock.ins.pas max_data_len). }
  mac_socket_max_data_len = 1024;

  { The cleanup handler bit MAC_$OPEN sets with PROC2_$SET_CLEANUP. }
  mac_cleanup_handler_bit = 16#0D;

type
  { The caller's record of MAC_$OPEN, 0x56 bytes.  The packet-type ranges
    at 0 are overwritten by the results: a variant record, the fields
    after the ranges in the first arm (ref 3.10.3).  The ranges are
    mac_os's type (mac_os/mac_os.ins.pas mac_os_$pkt_type_range_t),
    indexed from 0.  flags is the promiscuous flag (bit 7). }
  mac_$open_params_t = record
    case integer of
      1: (packet_types: array[0..9] of mac_os_$pkt_type_range_t;
                                                    { 0x00 }
          num_packet_types: integer;                { 0x50 }
          socket_count: integer;                    { 0x52 }
          flags: boolean);                          { 0x54 }
      2: (ec2_handle: ec2_$ptr_t;                   { 0x00 }
          mtu: integer32;                           { 0x04 }
          channel_num: pinteger);                   { 0x08 }
  end;

  { The caller's record of MAC_$SEND, MAC_OS's: MAC_$SEND copies its
    fields into one of MAC_OS's at the same offsets (mac/send.pas). }
  mac_$send_pkt_t = mac_os_$send_pkt_t;

  { The caller's record of MAC_$RECEIVE, 0x34 bytes.  MAC_$RECEIVE writes
    is_local, the link address, time as its longword and word (a
    time_$clock_t's first variant), frame_type, and walks the buffer
    chain from buffers.  The unused_ fields are the word rules' padding. }
  mac_$recv_pkt_t = record
    link_addr: mac_os_$link_addr_t;       { 0x00 }
    is_local: boolean;                    { 0x18 }
    unused_1a: integer;                   { 0x1A }
    buffers: mac_os_$buf_desc_t;          { 0x1C }
    unused_28: integer;                   { 0x28 }
    time: time_$clock_t;                  { 0x2A }
    frame_type: integer32;                { 0x30 }
  end;

{ The six routines, in map order.  The headings are the fragments'
  (mac/*.pas give the evidence for each mode). }

{ MAC_$OPEN - open a MAC channel on a port. }
procedure mac_$open(in port_num: integer;
                    in out params: mac_$open_params_t;
                    out status: status_$t); extern;

{ MAC_$CLOSE - close a MAC channel. }
procedure mac_$close(in channel: pinteger; out status: status_$t); extern;

{ MAC_$SEND - send a packet on a MAC channel. }
procedure mac_$send(in channel: pinteger; in out pkt_desc: mac_$send_pkt_t;
                    out bytes_sent: integer; out status: status_$t); extern;

{ MAC_$DEMUX - the receive callback of MAC channels: queue a packet on the
  channel's socket. }
procedure mac_$demux(in pkt: mac_os_$rcv_pkt_t; in port_num: integer;
                     in demux_flag: boolean; out status: status_$t); extern;

{ MAC_$RECEIVE - take the next packet off a MAC channel's socket. }
procedure mac_$receive(in channel: pinteger;
                       in out pkt_desc: mac_$recv_pkt_t;
                       out status: status_$t); extern;

{ MAC_$NET_TO_PORT_NUM - the port number of a network. }
procedure mac_$net_to_port_num(in net_id: integer32; out port_num: integer);
  extern;
