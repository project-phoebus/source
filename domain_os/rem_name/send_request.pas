{ rem_name_$send_request - send a request to a naming server and check
  the reply.

  Image addresses:
    sau2  0x00E4A4C8  rem_name_$send_request

  - The module's request template, its first word or-ed with flags, is
    the packet's info; the request goes to the naming service's socket.
  - A failure's status also goes to REM_NAME_$LAST_STATUS.  The result
    is true on success.

  Status stored:
    status_$ok: the reply is good
    pkt_$sar_internet's status: the transport failed
    the reply's status: the reply is shorter than its header, for
      another opcode, or carries a status of its own
}

{ TODO(pascal) the 30-byte template against PKT_$SAR_INTERNET's 32-byte
  pkt_$info_t

  The template is copied whole as 30 bytes and passed as
  PKT_$SAR_INTERNET's packet info, which pkt/pkt.ins.pas declares as
  pkt_$info_t, 32 bytes with a word pad_1e that no routine reads
  (ASKNODE_$INTERNET_INFO copies 30 bytes the same way); the formal is
  `univ'.  The other reading is a 30-byte pkt_$info_t, which would also
  explain pkt/pkt.pas's stand-in unused_66.  Not settled; changing
  pkt_$info_t touches PKT, NETLOG and the two PKT records' layout. }

{ TODO(pascal) 20 to 26 frame bytes above sar_result

  sar_result lies 40 bytes below the SAU2 frame's top.  Either the
  original declared a 20- to 26-byte local first (unused_20 and
  unused_24 hold the place, never addressed), or its result record is
  30 to 36 bytes rather than pkt_$sar_result_t's 10 (only the word at 8
  is known).  Not settled. }

function rem_name_$send_request(net: integer32;
                                node: integer32;
                                in request: univ pkt_$bytes_t;
                                req_size: pinteger;
                                flags: integer;
                                opcode: integer;
                                out response: univ rem_name_$reply_hdr_t;
                                resp_size: pinteger;
                                out resp_len: integer;
                                out status: status_$t): boolean;
  internal;
var
  unused_20: array[1..20] of char;        { the TODO above }
  unused_24: integer32;
  sar_result: pkt_$sar_result_t;
  template: rem_name_$config_t;
  resp_data: integer32;
  xport_status: status_$t;
  data_len: pinteger;
begin
  rem_name_$send_request := false;
  template := rem_name_$config;
  template[1] := template[1] ! flags;

  pkt_$sar_internet(net, node, rem_name_$sock, template,
                    rem_name_$service_delay, request, req_size, 0, 0,
                    sar_result, response, resp_size, resp_len,
                    resp_data, 0, data_len, xport_status);

  if xport_status.all <> status_$ok then begin
    status := xport_status;
    rem_name_$last_status := xport_status;
  end
  else if (resp_len < 18)
          or else (opcode <> response.opcode)
          or else (response.status.all <> status_$ok) then begin
    status := response.status;
    rem_name_$last_status := status;
  end
  else begin
    status.all := status_$ok;
    rem_name_$send_request := true;
  end;
end;
