{ NETLOG_$CNTL - start, stop or retune network event logging.

  Image addresses:
    sau2  0x00E71914  NETLOG_$CNTL
    sau9  0x3C47930C  NETLOG_$CNTL

  - cmd 0 sets logging up when it is not (the module's code and data
    wired, two buffer pages); 1 stops it when it is, sending a partly
    filled page; 0 and 2 then set the kinds and the two OK flags.
  - The map also names the routine NETLOG_$PROC_START.

  Status stored:
    status_$ok: logging was set up, stopped or retuned
    wp_$calloc's or netbuf_$getva's status: a buffer page could not be
      had; the set-up goes on
}

{ TODO(pascal) 2 frame bytes unexplained (stand-in unused_a)

  In the SAU2 frame ppn_shifted, pages_wired and the expression's
  temporary are addressed; i's slot is the loop index's.  One word is
  not explained: a word temporary right below the locals would lie
  there, so either a 2-byte local not translated (the stand-in unused_a)
  or a longword alignment of the temporary that is not seen elsewhere
  (word temporaries are word aligned in GET_BUILD_TIME). }

procedure netlog_$cntl(in cmd: integer; in node: integer32; in sock: integer;
                       in kinds: netlog_$kinds_t; out status: status_$t);
var
  ppn_shifted: integer32;
  pages_wired: integer;
  i: integer;                             { no register }
  unused_a: integer;                      { the stand-in (TODO) }
begin
  status.all := status_$ok;

  { stop }
  if (cmd = 1) and then initialized then begin
    initialized := false;
    netlog_$ok_to_log := false;
    netlog_$ok_to_log_server := false;
    if page_counts[current_buf_index] > 0 then begin
      send_page_index := current_buf_index;
      netlog_$done_cnt := netlog_$done_cnt + 1;
      netlog_$send_page;
    end;
    discard(netbuf_$rtnva(buffer_va[1]));
    discard(netbuf_$rtnva(buffer_va[2]));
    mmap_$free(buffer_ppn[1]);
    mmap_$free(buffer_ppn[2]);
    ok_to_send := false;
    page_counts[1] := 0;
    page_counts[2] := 0;
    for i := 1 to wired_page_count do
      wp_$unwire(wired_pages[i]);
  end;

  { start }
  if (cmd = 0) and then not initialized then begin
    wired_page_count := 0;
    mst_$wire_area(addr(netlog_$proc_start), addr(netlog_$proc_end),
                   wired_pages[1], netlog_max_wired_pages, wired_page_count);
    mst_$wire_area(addr(netlog_$data_start), addr(netlog_$data_end),
                   wired_pages[wired_page_count + 1],
                   netlog_max_wired_pages - wired_page_count, pages_wired);
    wired_page_count := wired_page_count + pages_wired;
    netlog_$node := node;
    netlog_$sock := sock;
    netlog_$kinds := kinds;
    wp_$calloc(buffer_ppn[1], status);
    wp_$calloc(buffer_ppn[2], status);
    ppn_shifted := lshft(buffer_ppn[1], 10);
    netbuf_$getva(ppn_shifted, buffer_va[1], status);
    ppn_shifted := lshft(buffer_ppn[2], 10);
    netbuf_$getva(ppn_shifted, buffer_va[2], status);
    current_buf_index := 1;
    netlog_$done_cnt := 0;
    page_counts[1] := 0;
    page_counts[2] := 0;
    current_buf_ptr := buffer_va[1];
    pkt_hdr.type1 := 99;
    pkt_hdr.type2 := 1;
    pkt_hdr.done_cnt := 0;
    ok_to_send := true;
    initialized := true;
  end;

  { the kinds and the flags }
  if (cmd = 0) or else (cmd = 2) then begin
    netlog_$kinds := kinds;
    netlog_$ok_to_log_server := ((21 in netlog_$kinds) or (20 in netlog_$kinds))
                                and initialized;
    netlog_$ok_to_log := ((netlog_$kinds - [20, 21]) <> []) and initialized;
  end;
end;
