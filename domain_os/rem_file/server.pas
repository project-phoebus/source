{ REM_FILE_$SERVER - serve one remote file request.

  Image addresses:
    sau2  0x00E63586  REM_FILE_$SERVER

  - One packet from socket 2, under the socket lock; every operation but
    UNLOCK_ALL runs with the lock released.
  - The DIR_ operations (16#2A..16#5C) go to DIR_$SERVER, the ACL_ ones
    (16#64..16#77) to ACL_$SERVER; the rest are served here, eight by
    the nested helpers (rem_file/server_*.pas).
  - A node not offering the file service refuses; a request of an
    unknown version becomes operation 2.
  - A reply that could not be sent truncates the object back for
    operation 6.

  Status stored (in the reply):
    status_$ok: the operation was served
    the operation's status: the served routine's
    status_$network_request_denied_by_remote_node: this node offers no
      file service
    file_$remote_lock_table_full, file_$bad_reply_received_from_remote_node,
      status_$network_data_length_too_large, status_$network_buffer_error:
      the request could not be served
}

procedure rem_file_$server;
label
  10, 20, 30, 40, 90;
var
  rcv: app_$receive_rec_t;
  unused_70: array[1..64] of char;     { stand-in }
  netbuf_hdr: pkt_$data_pages_t;
  response: rem_file_$server_resp_t;
  request: rem_file_$server_req_t;
  lock_info: file_$lock_info_t;
  dir_status: status_$t;
  dtv_unused: time_$clock_t;
  location_unused: integer32;
  netbuf_hdr_addr: integer32;
  log_info: rem_file_$log_info_t;
  clock_end: time_$clock_t;
  clock_start: time_$clock_t;
  clock_recv: time_$clock_t;
  local_status: status_$t;
  netbuf_va: integer32;
  lock_slot: linteger;
  zero_long: integer32;
  pkt_routing_key: integer32;
  crash_node: integer32;
  pkt_src_override: integer32;
  pkt_src_node: integer32;
  create_flags: integer;
  lock_flags: integer;
  seg_map_flag: ast_$seg_map_flags_t;
  send_extra_out: pinteger;
  send_len_out: integer;
  uid_retry: integer;
  tmp_index: integer;
  reply_hdr_len: pinteger;
  reply_len: pinteger;
  request_len: pinteger;
  pkt_request_id: pinteger;
  pkt_dest_sock: pinteger;
  lock_scan_index: pinteger;
  trunc_result: boolean;
  holds_lock: boolean;
  holds_netbuf: boolean;
  extra_len: pinteger;
  peer_node: linteger;
  bulk: pkt_$bytes_ptr_t;

%include 'rem_file/server_unmap_name.pas';
%include 'rem_file/server_get_entry.pas';
%include 'rem_file/server_set_attribute.pas';
%include 'rem_file/server_get_entry_sids.pas';
%include 'rem_file/server_drop_link.pas';
%include 'rem_file/server_truncate_delete.pas';
%include 'rem_file/server_generate_uid.pas';
%include 'rem_file/server_set_prot_attrib.pas';

begin
  ml_$exclusion_start(rem_file_$sock_lock);
  holds_lock := true;
  holds_netbuf := false;

  app_$receive(rem_file_server_socket, rcv, local_status);
  if local_status.all = status_$network_buffer_queue_is_empty then begin
    local_status.all := status_$network_buffer_queue_is_empty;
    goto 90;
  end;
  if local_status.all <> status_$ok then
    goto 90;

  { the arrival clock and the log word pair }
  clock_recv.high := rcv.src_addr;
  clock_recv.low := rcv.src_port;
  log_info.bits.qcount := rcv.queue_count;
  log_info.bits.node := pkt_$internet_hdr_ptr_t(rcv.reply)^.src_node;

  if netlog_$ok_to_log_server then
    time_$abs_clock(clock_start);

  { the file service's backlog }
  tmp_index := sock_$socket_ptr[2]^.queue_count;
  if tmp_index <= 8 then
    network_$file_backlog[tmp_index] := network_$file_backlog[tmp_index] + 1
  else
    network_$file_backlog[8] := network_$file_backlog[8] + 1;

  { the packet's header }
  pkt_src_override := rcv.hdr_f06;
  pkt_routing_key := rcv.hdr_f12;
  with pkt_$internet_hdr_ptr_t(rcv.reply)^ do begin
    extra_len := data_len;
    pkt_src_node := dest_node;
    peer_node := src_node;
    pkt_dest_sock := src_sock;
    pkt_request_id := request_id;
    request_len := min(hdr_len, 660);
  end;

  { the request, the header buffer, the pages }
  os_$data_copy(pkt_$bytes_ptr_t(rcv.data)^, request, request_len);
  netbuf_hdr_addr := rcv.data & (-16#400);
  netbuf_$rtn_hdr(netbuf_hdr_addr);
  netbuf_hdr := rcv.data_pages;

  { data pages with the request }
  if netbuf_hdr[1] <> 0 then begin
    if (request.req.hdr.opcode = dir_op_add_linku) or else
       (request.req.hdr.opcode = dir_op_resolve) then begin
      if extra_len > 1024 then
        goto 10;
      netbuf_$getva(netbuf_hdr[1], netbuf_va, local_status);
      bulk := pkt_$bytes_ptr_t(netbuf_va);
      if local_status.all <> status_$ok then
        crash_system(local_status);
      if request.req.hdr.opcode = dir_op_add_linku then
        request.dir.add_link.target_ptr := dir_$text_ptr_t(bulk)
      else begin
        request.dir.resolve.path_ptr := dir_$text_ptr_t(bulk);
        request.dir.resolve.link_buf := dir_$text_ptr_t(bulk);
      end;
      holds_netbuf := holds_lock;
    end
    else if request.req.hdr.opcode = rem_file_op_acl_create then begin
      if extra_len > 1024 then begin
      10:
        pkt_$dump_data(netbuf_hdr, extra_len);
        local_status.all := status_$network_data_length_too_large;
        goto 90;
      end;
      netbuf_$getva(netbuf_hdr[1], netbuf_va, local_status);
      bulk := pkt_$bytes_ptr_t(netbuf_va);
      if local_status.all <> status_$ok then
        crash_system(local_status);
      request.acl.acl_data := acl_$cache_slot_ptr_t(bulk);
      holds_netbuf := holds_lock;
    end
    else begin
      pkt_$dat_copy(netbuf_hdr, min(extra_len, 660 - request_len),
                    integer32(addr(request.bytes[request_len])));
      pkt_$dump_data(netbuf_hdr, extra_len);
    end;
  end;

  { the reply's header }
  response.reply.hdr.magic := rem_file_req_magic;
  response.reply.hdr.opcode := request.req.hdr.opcode + 1;
  response.reply.hdr.pkt_flag := 1;
  if not (network_service_file in network_$allowed_service.service) then
    begin
    response.reply.hdr.status.all :=
      status_$network_request_denied_by_remote_node;
    goto 30;
  end;

  if request.req.hdr.msg_type <> 1 then
    request.req.hdr.opcode := rem_file_op_bad_version;
  if request.req.hdr.opcode <> rem_file_op_unlock_all then begin
    ml_$exclusion_stop(rem_file_$sock_lock);
    holds_lock := false;
  end;

  { the DIR_ operations }
  if (request.req.hdr.opcode >= rem_file_op_dir_first) and then
     (request.req.hdr.opcode <= rem_file_op_dir_last) then begin
    if not holds_netbuf and then
       (request.req.hdr.opcode = dir_op_resolve) then begin
      request.dir.resolve.path_ptr :=
        dir_$text_ptr_t(addr(request.dir.raw[16#22]));
      netbuf_$get_dat(netbuf_hdr[1]);
      netbuf_$getva(netbuf_hdr[1], netbuf_va, local_status);
      bulk := pkt_$bytes_ptr_t(netbuf_va);
      if local_status.code <> 0 then
        crash_system(local_status);
      request.dir.resolve.link_buf := dir_$text_ptr_t(bulk);
      holds_netbuf := true;
    end
    else if (request.req.hdr.opcode = dir_op_dir_readu) or else
            (request.req.hdr.opcode = dir_op_read_linku) then begin
      netbuf_$get_dat(netbuf_hdr[1]);
      netbuf_$getva(netbuf_hdr[1], netbuf_va, local_status);
      bulk := pkt_$bytes_ptr_t(netbuf_va);
      if local_status.code <> 0 then
        crash_system(local_status);
      if request.req.hdr.opcode = dir_op_read_linku then
        request.dir.add_link.target_ptr := dir_$text_ptr_t(bulk)
      else
        request.dir.readu.buf_va := bulk;
      holds_netbuf := true;
    end
    else if not holds_netbuf and then
            (request.req.hdr.opcode = dir_op_add_linku) then
      request.dir.add_link.target_ptr :=
        dir_$text_ptr_t(addr(request.dir.add_link.name[
          request.dir.add_link.path_len + 1]));
    dir_$server(request, response, reply_len);
    if (request.req.hdr.opcode = dir_op_add_linku) and then
       holds_netbuf then
      goto 20;
    goto 40;
  end;

  { the ACL_ operations }
  if (request.req.hdr.opcode >= rem_file_op_acl_first) and then
     (request.req.hdr.opcode <= rem_file_op_acl_last) then begin
    if request.req.hdr.opcode = rem_file_op_acl_image then begin
      netbuf_$get_dat(netbuf_hdr[1]);
      netbuf_$getva(netbuf_hdr[1], netbuf_va, local_status);
      bulk := pkt_$bytes_ptr_t(netbuf_va);
      if local_status.code <> 0 then
        crash_system(local_status);
      request.acl.buf := acl_$cache_slot_ptr_t(bulk);
      holds_netbuf := true;
    end;
    acl_$server(request.acl, response.acl, reply_len);
    if request.req.hdr.opcode <> rem_file_op_acl_create then
      goto 40;
  20:
    netbuf_va := integer32(bulk);
    netbuf_$rtn_dat(netbuf_$rtnva(netbuf_va));
    holds_netbuf := false;
    goto 40;
  end;

  { the operations served here }
  case request.req.hdr.opcode of
    rem_file_op_set_attribute: begin
      server_set_attribute;
      goto 40;
    end;

    rem_file_op_neighbors: begin
      response.reply.nb_result :=
        file_$neighbors(request.req.uid, request.req.nb_uid2,
                        response.reply.hdr.status);
      reply_len := 10;
      goto 40;
    end;

    rem_file_op_truncate: begin
      server_truncate_delete;
      goto 40;
    end;

    rem_file_op_lock, rem_file_op_lock_ext: begin
      if request.req.hdr.opcode = rem_file_op_lock_ext then begin
        lock_flags := 2 ! request.sv_lock_flags;
        file_$priv_lock(request.req.uid, 0, request.req.lock_mode,
                        request.req.lock_type, true, lock_flags,
                        pkt_request_id, request.req.lock_key,
                        request.req.lock_node, pkt_routing_key,
                        addr(request.req.ext_exsid), request.req.ext_wait,
                        lock_slot, response.reply.reply_key,
                        response.reply.hdr.status);
        reply_len := 190;
      end
      else begin
        lock_flags := 16#8A;
        file_$priv_lock(request.req.uid, 0, request.req.lock_mode,
                        request.req.lock_type, true, lock_flags,
                        pkt_request_id, request.req.lock_key,
                        request.req.lock_node, pkt_routing_key, 0,
                        request.req.ext_wait, lock_slot,
                        response.reply.reply_key,
                        response.reply.hdr.status);
        reply_len := 16;
      end;

      if response.reply.hdr.status.all = file_$local_lock_table_full then
        begin
        response.reply.hdr.status.all := file_$remote_lock_table_full;
        goto 40;
      end;
      if response.reply.hdr.status.all <> status_$ok then
        goto 40;

      { the extended lock's location }
      if request.req.hdr.opcode = rem_file_op_lock_ext then begin
        response.reply.reply_loc := request.req.ext_loc;
        if dir_$uid_view_t(response.reply.reply_loc.uid).b0 = 0 then
          response.sv_uid_10 := response.reply.reply_loc.uid
        else
          ast_$get_attributes(response.reply.reply_loc, 16#81,
                              response.reply.reply_attrs,
                              response.reply.hdr.status);
        reply_len := 190;
        response.sv_one_08 := 1;
        goto 40;
      end;

      { the plain lock's clock }
      zero_long := 0;
      ast_$get_dtv(request.req.uid, zero_long, response.reply.dtv,
                   local_status);
      if request_len = 30 then begin
        response.reply.lock_word := lshft(response.reply.lock_word, 3) &
                                    16#F8;
        reply_len := 14;
        goto 40;
      end
      else begin
        reply_len := 16;
        response.sv_one_0e := 1;
        goto 40;
      end;
    end;

    rem_file_op_unlock: begin
      if request.req.unlock_release and then (request_len >= 34) then
        begin
        response.reply.reply_loc.uid := request.req.uid;
        response.reply.reply_loc.flags :=
          response.reply.reply_loc.flags - [6];
        ast_$get_attributes(response.reply.reply_loc, 16#280,
                            response.reply.reply_attrs, local_status);
        response.reply.dtu := response.reply.reply_attrs.clock_24;
        response.reply.attrs_valid := local_status.all = status_$ok;
      end;
      response.reply.unlock_result :=
        file_$priv_unlock(request.req.uid, 0, request.req.unlock_mode, 0,
                          true, request.req.unlock_key,
                          request.req.unlock_rem_key,
                          request.req.unlock_rem_node, response.reply.dtv,
                          response.reply.hdr.status);
      reply_len := 22;
      goto 40;
    end;

    rem_file_op_unlock_all: begin
      if network_$diskless and then
         (peer_node = network_$mother_node) then begin
        crash_show_string(rem_file_$diskless_crash_msg);
        crash_system(file_$comms_problem_with_remote_node);
      end;
      lock_scan_index := 0;
      repeat
        file_$read_lock_entryi(uid_$nil, lock_scan_index, lock_info,
                               local_status);
        if local_status.all <> status_$ok then
          exit;
        if (lock_info.owner_node & 16#FFFFF) = peer_node then
          discard(file_$priv_unlock(lock_info.file_uid, 0, 0, 0, true,
                                    lock_info.sequence, lock_info.context,
                                    lock_info.owner_node, dtv_unused,
                                    local_status));
      until false;
      area_$free_from(peer_node);
      if network_$really_diskless then
        goto 90;
      crash_node := peer_node;
      dir_$drop_mount(name_$node_uid, uid_$nil, crash_node, local_status);
      goto 90;
    end;

    rem_file_op_local_read_lock: begin
      file_$local_read_lock(request.req.uid, response.reply.reply_lock,
                            response.reply.hdr.status);
      reply_len := 42;
      goto 40;
    end;

    rem_file_op_name_get_entryu: begin
      server_get_entry_sids;
      goto 40;
    end;

    rem_file_op_local_verify: begin
      file_$local_lock_verify(request.req.verify_lock,
                              response.reply.hdr.status);
    end;

    rem_file_op_purify: begin
      ast_$purify(request.req.uid, 4 ! request.req.pur_flags,
                  request.req.pur_page, 0, 0, response.reply.hdr.status);
    end;

    rem_file_op_test: begin
      response.reply.hdr.status.all := status_$ok;
    end;

    rem_file_op_set_def_acl: begin
      if request.req.def_version <> 3 then
        response.reply.hdr.status.all :=
          file_$bad_reply_received_from_remote_node
      else begin
        if request.req.def_force then
          acl_$enter_super;
        dir_$old_set_default_acl(request.req.uid, request.req.def_acl_type,
                                 request.req.def_acl_uid,
                                 response.reply.hdr.status);
        if request.req.def_force then
          acl_$exit_super;
      end;
      if response.reply.hdr.status.all = status_$naming_directory_locked
        then begin
        response.reply.hdr.pkt_flag := -1;
        rem_file_$stale_link_count := rem_file_$stale_link_count + 1;
      end;
    end;

    rem_file_op_get_seg_map: begin
      zero_long := 0;
      if request_len = 20 then begin
        if request.req.seg_type then
          seg_map_flag := [ast_$seg_map_all_pages]
        else
          seg_map_flag := [];
        ast_$get_seg_map(request.req.uid, request.req.seg_index * 32768,
                         zero_long, 1, 16#20, seg_map_flag,
                         response.reply.seg_bits, response.reply.hdr.status);
      end
      else
        ast_$get_seg_map(request.req.uid, request.req.seg_offset * 1024,
                         zero_long, request.sv_seg_count,
                         request.sv_map_size, seg_map_flag,
                         response.reply.seg_bits, response.reply.hdr.status);
      reply_len := 40;
      goto 40;
    end;

    rem_file_op_invalidate: begin
      ast_$invalidate(request.req.uid, request.req.inv_start,
                      request.req.inv_count, request.req.inv_flag,
                      response.reply.hdr.status);
    end;

    rem_file_op_reserve: begin
      ast_$reserve(request.req.uid, request.req.res_start,
                   request.req.res_count, response.reply.hdr.status);
    end;

    rem_file_op_name_add_hard_linku: begin
      server_unmap_name(request.req.ahl_name, request.req.ahl_name_len);
      if request.req.ahl_force then
        acl_$enter_super;
      dir_$old_add_hard_linku(request.req.uid, request.req.ahl_name,
                              request.req.ahl_name_len,
                              request.req.ahl_file_uid, dir_status);
      response.reply.hdr.status := dir_status;
      if request.req.ahl_force then
        acl_$exit_super;
      if dir_status.all = status_$naming_directory_locked then begin
        response.reply.hdr.pkt_flag := -1;
        rem_file_$stale_link_count := rem_file_$stale_link_count + 1;
      end;
    end;

    rem_file_op_drop_hard_linku: begin
      server_drop_link;
      goto 40;
    end;

    rem_file_op_generate_uid: begin
      server_generate_uid;
      goto 40;
    end;

    rem_file_op_create_type_presr10: begin
      create_flags := 2;
      if request.req.presr10_index = 0 then
        create_flags := 3;
      discard(file_$priv_create(request.req.presr10_type, uid_$nil,
                                request.req.uid,
                                request.req.presr10_session, 0,
                                create_flags, nil,
                                response.reply.hdr.status));
      reply_len := 18;
      response.sv_index_10 := request.req.presr10_index;
      goto 40;
    end;

    rem_file_op_create_type: begin
      discard(file_$priv_create(request.req.create_type,
                                request.req.type_uid,
                                request.req.parent_uid2,
                                request.req.session_uid,
                                request.req.create_size,
                                2 ! request.req.create_flags,
                                addr(request.req.owner),
                                response.reply.hdr.status));
      if (response.reply.hdr.status.all = status_$ok) or else
         (response.reply.hdr.status.all = status_$vtoc_duplicate_uid) then
        begin
        response.reply.reply_loc.uid := request.req.session_uid;
        response.reply.reply_loc.flags :=
          response.reply.reply_loc.flags - [6];
        ast_$get_attributes(response.reply.reply_loc, 1,
                            response.reply.reply_attrs, local_status);
        if local_status.all <> status_$ok then
          response.reply.hdr.status := local_status;
      end;
      reply_len := 190;
      goto 40;
    end;

    rem_file_op_file_set_prot, rem_file_op_file_set_attrib: begin
      server_set_prot_attrib;
      goto 40;
    end;

    rem_file_op_create_area: begin
      if request_len < 28 then
        response.reply.ca_handle :=
          area_$create_from(peer_node, request.req.area_size,
                            request.req.area_size, request.req.area_caller,
                            response.reply.hdr.status)
      else
        response.reply.ca_handle :=
          area_$create_from(peer_node, request.req.area_size,
                            request.req.area_commit,
                            request.req.area_caller,
                            response.reply.hdr.status);
      response.reply.ca_pkt_size := 1024;
      reply_len := 12;
      goto 40;
    end;

    rem_file_op_delete_area: begin
      area_$delete_from(request.req.area_volx, peer_node,
                        request.req.area_caller, response.reply.hdr.status);
    end;

    rem_file_op_grow_area: begin
      if request_len < 28 then
        area_$grow_to(request.req.area_volx, request.req.area_size,
                      request.req.area_size, response.reply.hdr.status)
      else
        area_$grow_to(request.req.area_volx, request.req.area_size,
                      request.req.area_commit, response.reply.hdr.status);
    end;

    otherwise begin
      response.reply.hdr.opcode := rem_file_op_bad_version_reply;
      response.reply.hdr.status.all :=
        file_$bad_reply_received_from_remote_node;
    end;
  end;

30:
  reply_len := 8;

40:
  if netlog_$ok_to_log_server then
    time_$abs_clock(clock_end)
  else
    clock_end.high := time_$clockh;

  { the reply's header and its bulk data }
  if reply_len > 512 then begin
    reply_hdr_len := 512;
    extra_len := reply_len - 512;
    bulk := pkt_$bytes_ptr_t(addr(response.bytes[16#200]));
  end
  else begin
    reply_hdr_len := reply_len;
    if (request.req.hdr.opcode = dir_op_resolve) and then
       (response.reply.hdr.status.all = status_$ok) then
      extra_len := response.dir.link_count
    else if (request.req.hdr.opcode = dir_op_dir_readu) and then
            (response.reply.hdr.status.all = status_$ok) then
      extra_len := response.dir.size
    else if (request.req.hdr.opcode = dir_op_read_linku) and then
            ((response.reply.hdr.status.all = status_$ok) or else
             (response.reply.hdr.status.all = name_$pathname_truncated)) then
      extra_len := response.dir.len
    else if (request.req.hdr.opcode = rem_file_op_acl_image) and then
            (response.reply.hdr.status.all = status_$ok) then begin
      if request.acl.mode = 4 then
        extra_len := 1020
      else
        extra_len := 1024;
    end
    else
      extra_len := 0;
  end;

  if extra_len > 1024 then
    local_status.all := status_$network_buffer_error;
  if local_status.all = status_$ok then
    pkt_$send_internet(pkt_routing_key, peer_node, pkt_dest_sock,
                       pkt_src_override, pkt_src_node,
                       rem_file_server_socket, rem_file_$server_pkt_info,
                       pkt_request_id, response, reply_hdr_len, bulk^,
                       extra_len, send_len_out, send_extra_out,
                       local_status);

  if holds_netbuf then begin
    netbuf_va := integer32(bulk);
    netbuf_$rtn_dat(netbuf_$rtnva(netbuf_va));
    holds_netbuf := false;
  end;

  if local_status.all = status_$ok then begin
    { the log }
    if netlog_$ok_to_log_server then begin
      log_info.bits.log_op := 16#12;
      case request.req.hdr.opcode of
        rem_file_op_test: begin
          log_info.bits.log_op := 16#0B;
        end;
        rem_file_op_bad_version: begin
          log_info.bits.log_op := 16#12;
        end;
        rem_file_op_set_attribute: begin
          log_info.bits.log_op := 16#01;
        end;
        rem_file_op_code_06: begin
          log_info.bits.log_op := 0;
        end;
        rem_file_op_truncate: begin
          log_info.bits.log_op := 16#03;
        end;
        rem_file_op_lock: begin
          log_info.bits.log_op := 16#04;
        end;
        rem_file_op_unlock: begin
          log_info.bits.log_op := 16#05;
        end;
        rem_file_op_code_0e: begin
          log_info.bits.log_op := 16#09;
        end;
        rem_file_op_neighbors: begin
          log_info.bits.log_op := 16#02;
        end;
        rem_file_op_unlock_all: begin
          log_info.bits.log_op := 16#06;
        end;
        rem_file_op_purify: begin
          log_info.bits.log_op := 16#0A;
        end;
        rem_file_op_local_read_lock: begin
          log_info.bits.log_op := 16#07;
        end;
        rem_file_op_set_def_acl: begin
          log_info.bits.log_op := 16#24;
        end;
        rem_file_op_local_verify: begin
          log_info.bits.log_op := 16#08;
        end;
        rem_file_op_name_get_entryu: begin
          log_info.bits.log_op := 16#0D;
        end;
        rem_file_op_get_seg_map: begin
          log_info.bits.log_op := 16#0E;
        end;
        rem_file_op_invalidate: begin
          log_info.bits.log_op := 16#0F;
        end;
        rem_file_op_reserve: begin
          log_info.bits.log_op := 16#3D;
        end;
        rem_file_op_name_add_hard_linku: begin
          log_info.bits.log_op := 16#10;
        end;
        rem_file_op_code_62: begin
          log_info.bits.log_op := 16#11;
        end;
        rem_file_op_create_area: begin
          log_info.bits.log_op := 16#3A;
        end;
        rem_file_op_delete_area: begin
          log_info.bits.log_op := 16#3B;
        end;
        rem_file_op_grow_area: begin
          log_info.bits.log_op := 16#3C;
        end;
        rem_file_op_create_type: begin
          log_info.bits.log_op := 16#3E;
        end;
        rem_file_op_file_set_prot: begin
          log_info.bits.log_op := 16#3F;
        end;
        rem_file_op_file_set_attrib: begin
          log_info.bits.log_op := 16#40;
        end;
        rem_file_op_lock_ext: begin
          log_info.bits.log_op := 16#41;
        end;
        rem_file_op_generate_uid: begin
          log_info.bits.log_op := 16#42;
        end;
        rem_file_op_drop_hard_linku: begin
          log_info.bits.log_op := 16#1E;
        end;
        otherwise begin
          if (request.req.hdr.opcode >= rem_file_op_dir_first) and then
             (request.req.hdr.opcode <= rem_file_op_dir_last) then
            log_info.bits.log_op :=
              (request.req.hdr.opcode - rem_file_op_dir_first) div 2
              + 16#13;
          if (request.req.hdr.opcode >= rem_file_op_acl_first) and then
             (request.req.hdr.opcode <= rem_file_op_acl_last) then
            log_info.bits.log_op :=
              (request.req.hdr.opcode - rem_file_op_acl_first) div 2
              + 16#2F;
        end;
      end;
      netlog_$log_it(16#15, request.req.uid, 0, 0, log_info.w0,
                     log_info.w1,
                     integer32(clock_start.low32 - clock_recv.low32) div 250,
                     integer32(clock_end.low32 - clock_start.low32) div 250);
    end;
  end
  else if (response.reply.hdr.status.all = status_$ok) and then
          (request.req.hdr.opcode = rem_file_op_code_06) then
    ast_$truncate(response.reply.reply_uid, 0, 1, trunc_result,
                  local_status);

90:
  if holds_netbuf then begin
    netbuf_va := integer32(bulk);
    netbuf_$rtn_dat(netbuf_$rtnva(netbuf_va));
  end;
  if holds_lock then
    ml_$exclusion_stop(rem_file_$sock_lock);
end;
