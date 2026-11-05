{ NETWORK_$REPORT_FAILURE - record a transmit failure and announce it.

  Image addresses:
    sau2  0x00E103FA  NETWORK_$REPORT_FAILURE
    sau4  0x0F810D7A  NETWORK_$REPORT_FAILURE
    sau6  0x78010D46  NETWORK_$REPORT_FAILURE
    sau7  0x3C41225E  NETWORK_$REPORT_FAILURE
    sau8  0x03C1170E  NETWORK_$REPORT_FAILURE
    sau9  0x3C412822  NETWORK_$REPORT_FAILURE

  - NETWORK_$FAILURE_REC gets the clock's high longword, true, this node
    and a failure type: 1 for a biphase error, else 3.
  - A 24-byte message, 16#0003000E and the type, goes to socket 4 of the
    "node" the type names, flags 16#90.
  - The failure type is passed as NETWORK_$GETHDR's node and the
    header's destination node; the send's status is not tested.

  Status stored: none.
}

{ TODO(pascal) the 0x1E-byte copy of NETWORK_$SERVER_PKT_INFO

  The server's packet info is copied into pkt_info as seven longwords
  and a word, 30 bytes, as REM_NAME's and MSG's templates are
  (rem_name/send_request.pas's TODO(pascal); msg/msg.ins.pas
  msg_$template_t), but network_$server_pkt_info and pkt_info are
  pkt/pkt.ins.pas pkt_$info_t, 32 bytes (pad_1e), whose record
  assignment copies eight longwords (dpc's).
  The block fits a 30-byte type too: network_$request_pkt_info follows
  at +0x20, 8 aligned.  Not settled; changing pkt_$info_t
  touches PKT, NETLOG and this block. }

procedure network_$report_failure(in xmit_status: ring_$csr_t);
var
  pkt_info: pkt_$info_t;
  msg: network_$failure_msg_t;
  send_info: net_io_$send_info_t;
  hdr_pa: integer32;
  hdr: pkt_$hdr_ptr_t;
  hdr_va: pkt_$hdr_ptr_t;
  status: status_$t;
  timeout: pinteger;
  retry: integer;
  port: integer;
  hdr_len: integer;
begin
  network_$failure_rec.timestamp := time_$clockh;
  network_$failure_rec.flag := true;
  network_$failure_rec.node_id := node_$me;
  if ring_sendp_res_biphase in xmit_status then
    network_$failure_rec.failure_type := 1
  else
    network_$failure_rec.failure_type := 3;

  msg.kind := 16#0003000E;
  msg.failure_type := network_$failure_rec.failure_type;
  pkt_info := network_$server_pkt_info;
  pkt_info.flags := 16#90;

  network_$gethdr(network_$failure_rec.failure_type, hdr_va, hdr_pa);
  hdr := hdr_va;
  pkt_$bld_internet_hdr(0, network_$failure_rec.failure_type, 4, -1,
                        node_$me, 0, pkt_info, 0, msg, 24, 0, port,
                        hdr^, hdr_len, retry, timeout, status);

  if status.all = status_$ok then begin
    hdr_va := hdr;
    net_io_$send(port, hdr_va, hdr_pa, hdr_len, 0, 0, 0,
                 network_$report_send_flags, send_info, status);
  end;

  if hdr <> nil then begin
    hdr_va := hdr;
    network_$rtnhdr(hdr_va);
  end;
end;
