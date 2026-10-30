{ ASKNODE_$INTERNET_INFO - answer a node-information request, locally or
  by asking the node.

  Image addresses:
    sau2  0x00E645EA  ASKNODE_$INTERNET_INFO

  - For this node (or node 0) the reply comes from local state, one
    `case' arm per request type; the reply's status is the arm's.
  - For another node, only when this node serves paging requests:
    PKT_$SAR_INTERNET, once more through DIR_$FIND_NET when req_len is
    -1; an answer's node goes into the hints.
  - A TODO(pascal) after the routine names the place the Pascal cannot
    give the image's code.

  Status stored:
    status_$ok: a local request was answered
    status_$network_unknown_request_type: a local request of an unknown
      type
    status_$network_request_denied_by_local_node: this node serves no
      paging requests
    network_$ring_info's status: request 16#1F to another node
    pkt_$sar_internet's status: the exchange succeeded, or failed (its
      fail bit set)
    status_$network_unexpected_reply_type: the reply's type is not
      req_type + 1
    status_$network_bad_asknode_version_number: the reply's version is
      not ours
}

procedure asknode_$internet_info(in req_type: pinteger;
                                 in node_id: linteger;
                                 in req_len: integer32;
                                 in param: univ asknode_$param_t;
                                 in resp_len: integer;
                                 var result: univ asknode_$info_reply_t;
                                 out status: status_$t);
type
  { The request the remote path sends, 0x18 bytes (PKT_$SAR_INTERNET's
    template and its length): the version, the type, and the parameter
    block's part the type needs (asknode/asknode_info.ins.pas's
    records).  The named tags are request codes
    (asknode/asknode.ins.pas); 0, 1 and 2 are views, not codes. }
  request_t = record
    version: integer;                     { 0x00 }
    req_type: pinteger;                   { 0x02 }
    case integer of
      0: (data: array[1..20] of char);    { 0x04..0x17 }
      1: (uid: uid_$t);                   { 0x04 }
      asknode_$req_signal: (sig: asknode_$signal_t); { 0x04 }
      asknode_$req_signal2: (sig2: asknode_$signal2_t); { 0x04 }
      asknode_$req_log_control: (log_ctl: asknode_$log_ctl_t); { 0x04 }
      asknode_$req_log_read: (log: asknode_$log_req_t); { 0x04 }
      asknode_$req_port_info: (port: asknode_$port_key_t); { 0x04 }
      2: (long: integer32);               { 0x04 }
  end;
  { The network and node a request goes to, 8 bytes: NETWORK_$RING_INFO's
    node address (`in uid_$t'), PKT_$SAR_INTERNET's routing key (the
    first longword), HINT_$ADDI's address (`in hint_$addr_t'): two views
    of one record. }
  node_addr_t = record
    case integer of
      1: (addr: hint_$addr_t);            { flags (the network), node_id }
      2: (uid: uid_$t);
  end;
  { HINT_$GET_HINTS's key, 8 bytes: UID_$NIL with the node merged into
    its low longword's 20-bit node field. }
  hint_key_t = record
    case integer of
      1: (uid: uid_$t);
      2: (high: integer32;                { 0x00 }
          low: asknode_$node_word_t);     { 0x04 }
  end;
  uid_list_ptr_t = ^proc2_$uid_list_t;
var
  local_status: status_$t;
  has_stats: boolean;
  uid_copy: uid_$t;
  stats: disk_$stats_t;
  unit: integer;
  start_index: integer32;
  more: boolean;
  next_index: integer32;
  rl_param: array[1..3] of integer32;
  kinds: netlog_$kinds_t;
  disp_info: smd_disp_info_result_t;
  sub_status: status_$t;
  peb_flags: peb_$info_bits_t;
  peb_byte: char;
  real_pages: linteger;
  mnt: disk_$mnt_info_t;
  vol: integer;
  i: integer;
  k: integer;
  uids: uid_list_ptr_t;
  port_index: integer;
  rip_i: pinteger;
  loadav: proc1_$loadav_t;
  pid: integer;
  asid: pinteger;
  ws_index: pinteger;
  ws_page_count: linteger;
  ws_field_14: linteger;
  ws_max_pages: linteger;
  n_devices: pinteger;
  disp_unit: pinteger;
  disp_uid: uid_$t;
  node_addr: node_addr_t;
  retried: boolean;
  request: request_t;
  extra_len: pinteger;
  hint_key: hint_key_t;
  hints: hint_$addr_list_t;
  tpl: asknode_$template_t;
  sar_result: pkt_$sar_result_t;
  tpl_len: integer;
  data_len: pinteger;
begin
  if (node_id = node_$me) or else (node_id = 0) then begin
    local_status.all := status_$ok;
    status.all := status_$ok;
    result.status.all := status_$ok;
    if result.version <> 2 then
      result.version := 3;

    case req_type of
      asknode_$req_stats: begin
        result.w_08 := 3;
        result.node := node_$me;
        result.w_0e := 1;
        result.info_rqst_cnt := network_$info_rqst_cnt;
        result.pagin_rqst_cnt :=
          network_$pagin_rqst_cnt + network_$mult_pagin_rqst_cnt;
        result.pagout_rqst_cnt := network_$pagout_rqst_cnt;
        result.read_call_cnt := network_$read_call_cnt;
        result.write_call_cnt := network_$write_call_cnt;
        result.read_viol_cnt := network_$read_viol_cnt;
        result.write_viol_cnt := network_$write_viol_cnt;
        result.bad_chksum_cnt := network_$bad_chksum_cnt;
        result.ring := ring_$data[0];
        disk_$get_stats(0, 0, 0, has_stats, result.disk);
        result.mem := mem_$mem_rec;
        if mmap_$real_pages <= 16#FFFF then
          result.mem.board_errors[0] := mmap_$real_pages
        else
          result.mem.board_errors[0] := 0;
      end;
      asknode_$req_disk_info: begin
        disk_$get_stats(0, param.cnum, param.unit, result.has_disk_stats,
                        result.disk_stats);
      end;
      asknode_$req_timezone: begin
        result.tz := cal_$timezone;
      end;
      asknode_$req_paging_info: begin
        result.diskless := network_$diskless;
        if network_$diskless then
          result.paging_node := network_$paging_file_uid.low & 16#FFFFF
        else
          result.paging_node := node_$me;
      end;
      asknode_$req_root_uid, asknode_$req_node_uid: begin
        if req_type = 4 then
          result.uid := name_$get_node_uid
        else
          result.uid := name_$get_root_uid;
        result.status.all := status_$ok;
        result.neg_high := -result.uid.high;
        if network_$diskless then
          result.node_word.bits.node := network_$mother_node
        else
          result.node_word.bits.node := node_$me;
        result.one_minus_high := 1 - result.uid.high;
        result.network := route_$port[0].network;
      end;
      asknode_$req_disk_stats: begin
        for unit := 0 to 3 do begin
          disk_$get_stats(4, 0, unit, has_stats, stats);
          result.disks[unit] := stats;
        end;
      end;
      asknode_$req_boot_time: begin
        result.boot_time := time_$boot_time;
        result.current_clockh := time_$current_clockh;
      end;
      asknode_$req_volume_info: begin
        volx_$get_info(param.vol_idx, result.dir_uid, result.free_blocks,
                       result.total_blocks, local_status);
      end;
      asknode_$req_proc_list: begin
        proc2_$list(result.proc_uids, 16#39, result.n_procs);
        if (result.version <= 2) and then (result.n_procs > 16#19) then
          result.n_procs := 16#19;
        local_status.all := status_$ok;
      end;
      asknode_$req_zombie_list: begin
        start_index := 0;
        proc2_$zombie_list(result.proc_uids, 16#39, result.n_procs,
                           start_index, more, next_index);
        local_status.all := status_$ok;
      end;
      asknode_$req_proc_list2: begin
        proc2_$list2(result.proc_uids2, 16#3E, result.n_procs2,
                     param.list_start, result.more, result.next_index);
        local_status.all := status_$ok;
      end;
      asknode_$req_zombie_list2: begin
        proc2_$zombie_list(result.proc_uids2, 16#3E, result.n_procs2,
                           param.list_start, result.more,
                           result.next_index);
        local_status.all := status_$ok;
      end;
      asknode_$req_signal: begin
        proc2_$signal_pgroup_os(param.sig.uid, 16#13, param.sig.param,
                                local_status);
      end;
      asknode_$req_proc_info: begin
        proc2_$get_info(param.uid, result.proc_info, 504,
                        local_status);
      end;
      asknode_$req_build_time: begin
        get_build_time(result.build_time, result.build_len);
      end;
      asknode_$req_uids: begin
        result.n_uids := 6;
        uid_copy := name_$get_root_uid;
        result.root_uid := uid_copy;
        uid_copy := name_$get_node_uid;
        result.node_uid := uid_copy;
        uid_copy := name_$get_node_data_uid;
        result.status.all := status_$ok;
        result.node_data_uid := uid_copy;
        result.paging_uid := network_$paging_file_uid;
        if network_$diskless then
          result.home_low.bits.node := network_$mother_node
        else
          result.home_low.bits.node := node_$me;
        result.home_network := route_$port[0].network;
      end;
      asknode_$req_network_diag: begin
        result.diag_version := 3;
        result.diag_diskless := network_$diskless;
        result.diag_mother := network_$mother_node;
        result.diag_ring := ring_$data[0];
        result.diag_failure := network_$failure_rec;
        result.diag_swdiag.data := ring_$swdiag_data;
        result.diag_swdiag.rcvcnt := ring_$swdiag_rcvcnt;
        result.diag_swdiag.nodeid := ring_$swdiag_nodeid;
        result.xmit_biphase := ring_$xmit_biphase;
        result.rcv_biphase := ring_$rcv_biphase;
        result.xmit_esb := ring_$xmit_esb;
        result.rcv_esb := ring_$rcv_esb;
      end;
      asknode_$req_proc_info2: begin
        if (param.pid = 0) or else (param.pid > 16#40) then
          local_status.all := status_$illegal_process_id
        else
          proc2_$info(0, param.pid, result.proc_info, 504,
                      local_status);
      end;
      asknode_$req_proc_upids: begin
        proc2_$get_upids(param.uid, result.upid, result.uppid,
                         result.upgid, local_status);
      end;
      asknode_$req_log_control: begin
        if param.log_ctl.mode = 0 then
          ringlog_$cntl(ringlog_$cmd_clear, rl_param, status)
        else
          ringlog_$cntl(ringlog_$cmd_stop, rl_param, status);
        if status.all = status_$ok then begin
          kinds := param.log_ctl.kinds;
          netlog_$cntl(param.log_ctl.cmd, param.log_ctl.node,
                       param.log_ctl.sock, kinds, status);
        end;
      end;
      asknode_$req_system_info: begin
        result.sys_version := 16#11;
        result.machine_id := prom_$machine_id.id;
        smd_$inq_disp_info(1, disp_info, sub_status);
        if disp_info.display_type = smd_$none then
          smd_$inq_disp_info(2, disp_info, sub_status);
        result.display_type := disp_info.display_type;
        peb_$get_info(peb_flags, peb_byte);
        result.peb_flags := peb_flags;
        real_pages := mmap_$real_pages;
        if real_pages <= 16#FFFF then
          result.real_pages_w := real_pages
        else
          result.real_pages_w := 0;
        result.sys_diskless := network_$diskless;
        result.sys_paging_node := network_$paging_file_uid.low & 16#FFFFF;
        disk_$get_mnt_info(cal_$boot_volx, 16#2A, mnt, sub_status);
        if (not mnt.flags.mounted) or else (sub_status.all <> status_$ok)
           or else (mnt.dev_type <> 0) then
          result.boot_w := 0;
        result.system_rev := mmu_$system_rev;
        if gpu_$present then
          result.gpu := 1
        else
          result.gpu := 0;
        io_$get_config(result.io_config[1], result.io_config[2],
                       result.io_config[3], result.io_config[4]);
        result.n_vols := 0;
        for vol := 1 to 10 do begin
          disk_$get_mnt_info(vol, 16#2A, mnt, sub_status);
          if ((mnt.dev_type = 0) or (mnt.dev_type = 4))
             and then mnt.flags.mounted
             and then (sub_status.all = status_$ok)
             and then (not mnt.flags.logical) then begin
            result.n_vols := result.n_vols + 1;
            result.vol_types[result.n_vols] := mnt.dev_type;
            result.vol_units[result.n_vols] := mnt.unit_id;
          end;
        end;
        result.real_pages := real_pages;
        result.w_50 := 1;
      end;
      asknode_$req_net_stats: begin
        result.ns_version := 1;
        result.paging_backlog := network_$paging_backlog;
        result.paging_overflow := ring_$paging_overflow;
        result.file_backlog := network_$file_backlog;
        result.file_overflow := ring_$file_overflow;
        result.overflow_overflow := ring_$overflow_overflow;
        result.delivery_failed := ring_$delivery_failed;
        result.net_2long1 := network_$2long1;
        result.attrib_pagout :=
          network_$attrib_rqst_cnt + network_$pagout_rqst_cnt;
        result.rem_file_2long1 := rem_file_$2long1;
        result.l_60 := 0;
        result.xmitcnt := ring_$data[0].xmitcnt;
        result.xmit_waited := ring_$xmit_waited;
        result.send_null_cnt := ring_$send_null_cnt;
        result.clobbered_hdr := ring_$clobbered_hdr;
        result.rcvcnt := ring_$data[0].rcvcnt;
        result.rcv_int_cnt := ring_$rcv_int_cnt;
        result.busy_on_rcv_int := ring_$busy_on_rcv_int;
        result.abort_cnt := ring_$abort_cnt;
        result.wakeup_cnt := ring_$wakeup_cnt;
        result.bad_data_cnt := ring_$bad_data_cnt;
        result.ns_info_rqst := network_$info_rqst_cnt;
        result.ns_pagin := network_$pagin_rqst_cnt;
        result.ns_mult_pagin := network_$mult_pagin_rqst_cnt;
        result.ns_pagout := network_$pagout_rqst_cnt;
        result.ns_read_call := network_$read_call_cnt;
        result.ns_write_call := network_$write_call_cnt;
        result.ns_read_viol := network_$read_viol_cnt;
        result.ns_write_viol := network_$write_viol_cnt;
        result.ns_bad_chksum := network_$bad_chksum_cnt;
        result.ns_attrib_rqst := network_$attrib_rqst_cnt;
        result.ns_set_attrib_call := network_$set_attrib_call_cnt;
        result.ns_rcv_read_ahead := network_$rcv_read_ahead;
      end;
      asknode_$req_proc_pid: begin
        result.pid := proc2_$get_pid(param.uid, local_status);
      end;
      asknode_$req_failure_rec: begin
        if network_$activity_flag then
          network_$failure_rec.flag := false;
        result.failure := network_$failure_rec;
      end;
      asknode_$req_log_read: begin
        if 0 in param.log.flags then begin
          log_$read2(result.log_buf, param.log.offset, 1024,
                     result.log_len);
          local_status.code := -1;
        end
        else
          log_$read(result.log_buf, param.log.max_len, result.log_len);
      end;
      asknode_$req_proc1_list: begin
        proc1_$get_list(result.p1_count, result.p1_list);
        local_status.all := status_$ok;
      end;
      asknode_$req_signal2: begin
        case param.sig2.selector of
          0, 1:
            proc2_$signal_os(param.sig2.uid, 16#13, param.sig2.param,
                             local_status);
          2, 3:
            proc2_$signal_pgroup_os(param.sig2.uid, 16#13,
                                    param.sig2.param, local_status);
          otherwise
            status.all := status_$network_unknown_request_type;
        end;
      end;
      asknode_$req_route_port: begin
        result.route_network := route_$port[0].network;
      end;
      asknode_$req_port_list: begin
        result.version := 4;
        result.n_ports := 0;
        for i := 0 to 7 do
          if route_$portp[i]^.active <> 0 then begin
            result.n_ports := result.n_ports + 1;
            result.ports[result.n_ports].port_type :=
              route_$portp[i]^.port_type;
            result.ports[result.n_ports].socket := route_$portp[i]^.socket;
          end;
        uids := uid_list_ptr_t(addr(result.ports[result.n_ports + 1]));
        k := 0;
        for i := 0 to 7 do
          if route_$portp[i]^.active <> 0 then begin
            k := k + 1;
            uids^[k] :=
              net_io_$driver_ptr_t(route_$portp[i]^.driver_info)^.network_uid;
          end;
      end;
      asknode_$req_port_info: begin
        port_index := route_$find_port(param.port.port_type,
                                       param.port.socket);
        if port_index = -1 then
          local_status.all := status_$internet_unknown_network_port
        else
          route_$short_port(route_$portp[port_index]^, result.short_port);
      end;
      asknode_$req_route_stats: begin
        result.rs_version := 3;
        result.routing := route_$n_routing_ports > 1;
        result.std_routing := route_$std_n_routing_ports > 1;
        if result.routing or result.std_routing then begin
          result.start_time := route_$start_time;
          result.netbuf_alloc := route_$netbuf_alloc;
          result.pkts_routed := route_$pkts_routed;
          result.q_oflo := route_$q_oflo;
          result.misroute := route_$misroute;
          result.too_far := route_$too_far;
          result.dlen_err := route_$dlen_err;
          result.std_pkts_routed := route_$std_pkts_routed;
          result.std_misroute := route_$std_misroute;
          result.std_too_far := route_$std_too_far;
          result.std_dlen_err := route_$std_dlen_err;
        end;
      end;
      asknode_$req_device_stat2, asknode_$req_device_stat: begin
        port_index := route_$find_port(param.port.port_type,
                                       param.port.socket);
        if port_index = -1 then
          local_status.all := status_$internet_unknown_network_port
        else begin
          result.port_clock := route_$portp[port_index]^.clock_4e;
          result.port_counts := route_$portp[port_index]^.counts;
          result.stat_offset := integer32(addr(result.dev_stats))
                                - integer32(addr(result.port_clock));
          case req_type of
            asknode_$req_device_stat:
              net_io_$device_stat(param.port.port_type, param.dev_unit,
                                  16#80, uid_copy, addr(result.dev_stats),
                                  result.stat_len, local_status);
            asknode_$req_device_stat2:
              net_io_$device_stat2(param.port.port_type, param.dev_unit,
                                   16#80, uid_copy, addr(result.dev_stats),
                                   result.stat_len, local_status);
          end;
          result.dev_uid := uid_copy;
          if param.port.port_type = route_$port_type_ring then
            result.port_counts.stat_long_54 :=
              ring_$data[param.dev_unit].rcvcnt;
          result.max_data_len :=
            net_io_$driver_ptr_t(
              route_$portp[port_index]^.driver_info)^.max_data_len;
        end;
      end;
      asknode_$req_net_route: begin
        if (param.route_net = 0)
           or else (param.route_net = route_$port[0].network) then begin
          result.nr_network := route_$port[0].network;
          { the TODO(pascal) below the routine }
          result.nr_nexthop := 0;
          result.nr_expiration := -1;
          result.nr_metric := 0;
          result.nr_pkts := rip_$stats.local_net_pkts;
          route_$short_port(route_$portp[0]^, result.nr_port);
          result.nr_state := 1;
        end
        else begin
          local_status.all := status_$network_unknown_network;
          rip_i := 0;
          for i := 0 to 63 do begin
            with rip_$info[i] do
              if (network = param.route_net)
                 and then (routes[0].flags.state <> 0) then begin
                result.nr_network := network;
                result.nr_nexthop := routes[0].nexthop.host_lo & 16#FFFFF;
                result.nr_expiration := routes[0].expiration;
                result.nr_metric := routes[0].metric;
                result.nr_state := routes[0].flags.state;
                result.nr_pkts := rip_$stats.net_pkts[rip_i];
                route_$short_port(route_$portp[routes[0].port]^,
                                  result.nr_port);
                local_status.all := status_$ok;
                exit;
              end;
            rip_i := rip_i + 1;
          end;
        end;
      end;
      asknode_$req_queue_depth: begin
        result.qd_count := route_$netbuf_alloc;
        result.qd_oflo := route_$q_oflo;
        for i := 0 to result.qd_count do
          result.qd_depth[i] := route_$q_depth[i];
      end;
      asknode_$req_boot_device: begin
        result.boot_device := os_$boot_device;
      end;
      asknode_$req_loadav: begin
        proc1_$get_loadav(loadav);
        result.loadav := loadav;
      end;
      asknode_$req_proc_ws_info: begin
        pid := proc2_$get_pid(param.uid, local_status);
        if local_status.all = status_$ok then begin
          asid := proc2_$get_asid(param.uid, local_status);
          if local_status.all = status_$ok then begin
            mmap_$get_ws_index(pid, ws_index, local_status);
            if local_status.all = status_$ok then begin
              mmap_$get_ws_siz(ws_index, ws_page_count, ws_field_14,
                               ws_max_pages, local_status);
              if local_status.all = status_$ok then begin
                result.ws_page_count := ws_page_count;
                result.ws_field_14 := ws_field_14;
                result.ws_max_pages := ws_max_pages;
                mst_$get_private_size(asid, result.priv_size,
                                      result.priv_rw_size, local_status);
              end;
            end;
          end;
        end;
      end;
      asknode_$req_rev_info: begin
        os_$get_rev_info(result.rev);
      end;
      asknode_$req_display_list: begin
        n_devices := smd_$n_devices;
        result.n_displays := n_devices;
        result.disp_entry_size := 18;
        for disp_unit := 1 to n_devices do begin
          smd_$inq_disp_uid(disp_unit, disp_uid, result.status);
          result.displays[disp_unit].uid := disp_uid;
          smd_$inq_disp_info(disp_unit, disp_info, result.status);
          result.displays[disp_unit].display_type :=
            disp_info.display_type;
          result.displays[disp_unit].dims := disp_info.dims;
        end;
        if (result.n_displays > 1)
           and then (result.displays[1].display_type < smd_$color4_display)
        then begin
          result.n_displays := 1;
          result.displays[1] := result.displays[2];
        end;
      end;
      otherwise begin
        status.all := status_$network_unknown_request_type;
      end;
    end;

    result.response_type := req_type + 1;
    result.status := local_status;
  end
  else if not (network_service_paging in network_$allowed_service.service)
  then
    status.all := status_$network_request_denied_by_local_node
  else if req_type = asknode_$req_network_diag then begin
    if result.version <> 2 then
      result.version := 3;
    result.response_type := req_type + 1;
    node_addr.addr.flags := req_len;
    if node_addr.addr.flags = -1 then begin
      node_addr.addr.flags := 0;
      retried := false;
    end;
    node_addr.addr.node_id := node_id;
    repeat
      network_$ring_info(node_addr.uid, result.ring_info, status);
      if (status.all <> status_$network_transmit_failed)
         or else (req_len <> -1) or else retried then
        exit;
      node_addr.addr.flags := dir_$find_net(name_$root_uid, node_id);
      if node_addr.addr.flags = 0 then
        exit;
      retried := true;
    until false;
    result.status := status;
  end
  else begin
    request.version := 3;
    request.req_type := req_type;
    extra_len := 0;
    case req_type of
      asknode_$req_proc_pid, asknode_$req_proc_upids, asknode_$req_proc_info,
      asknode_$req_proc_ws_info: begin
        request.uid := param.uid;
      end;
      asknode_$req_signal: begin
        request.sig := param.sig;
      end;
      asknode_$req_log_control: begin
        request.log_ctl := param.log_ctl;
      end;
      asknode_$req_signal2: begin
        request.sig2 := param.sig2;
      end;
      asknode_$req_device_stat2, asknode_$req_device_stat,
      asknode_$req_port_info: begin
        request.port := param.port;
      end;
      asknode_$req_disk_info: begin
        request.long := param.long;
      end;
      asknode_$req_log_read: begin
        request.log := param.log;
        if 0 in param.log.flags then
          extra_len := 1024
        else
          extra_len := min(param.log.max_len, 1024);
      end;
      otherwise begin
        request.long := param.long;
      end;
    end;
    node_addr.addr.node_id := node_id;
    node_addr.addr.flags := req_len;
    if node_addr.addr.flags = -1 then begin
      hint_key.uid := uid_$nil;
      hint_key.low.bits.node := node_id;
      discard(hint_$get_hints(hint_key.uid, hints));
      node_addr.addr.flags := hints[1].flags;
      retried := false;
    end;
    tpl := asknode_$pkt_info;
    repeat
      pkt_$sar_internet(node_addr.addr.flags, node_id, 4, tpl, 6, request,
                        24, 0, 0, sar_result, result, resp_len, tpl_len,
                        result.data, extra_len, data_len, status);
      if (not ((status.all = status_$network_transmit_failed)
               or else (status.all =
                        status_$network_remote_node_failed_to_respond)))
         or else (req_len <> -1) or else retried then
        exit;
      node_addr.addr.flags := dir_$find_net(name_$root_uid, node_id);
      if node_addr.addr.flags = 0 then
        exit;
      retried := true;
    until false;
    if status.all <> status_$ok then begin
      status.fail := true;
      return;
    end;
    if result.response_type <> req_type + 1 then begin
      status.all := status_$network_unexpected_reply_type;
      return;
    end;
    if (result.version <> request.version)
       and then (result.version <> 2)
       and then (asknode_$protocol_version <> 3) then begin
      status.all := status_$network_bad_asknode_version_number;
      return;
    end;
    if result.status.all = status_$ok then
      case request.req_type of
        asknode_$req_volume_info:
          hint_$addi(result.dir_uid, node_addr.addr);
        asknode_$req_root_uid, asknode_$req_node_uid:
          if result.one_minus_high + result.uid.high = 1 then begin
            node_addr.addr.node_id := result.node_word.all & 16#FFFFF;
            node_addr.addr.flags := result.network;
            hint_$addi(result.uid, node_addr.addr);
          end
          else if (result.neg_high + result.uid.high = 0)
                  and then ((result.node_word.all & 16#FFFFF) = node_id)
          then
            hint_$addi(result.uid, node_addr.addr);
        asknode_$req_uids:
          if result.n_uids >= 6 then begin
            node_addr.addr.node_id := result.home_low.all & 16#FFFFF;
            node_addr.addr.flags := result.home_network;
            uid_copy := result.root_uid;
            hint_$addi(uid_copy, node_addr.addr);
          end
          else if (result.n_uids >= 5)
                  and then ((result.home_low.all & 16#FFFFF) = node_id)
          then begin
            uid_copy := result.root_uid;
            hint_$addi(uid_copy, node_addr.addr);
          end;
      end;
    if request.req_type = asknode_$req_log_read then
      result.log_len := data_len;
  end;
end;

{ TODO(pascal) INTERNET_INFO's request 16#41: the local route copied from a
  constant in the code

  In the SAU2 image the local network's route is a 10-byte block copy
  from a constant cell after the routine: the next hop 0, the expiration
  -1, the metric 0.  As FLP_$DINIT's label record (flp/dinit.pas, the
  TODO there): the reference has no record constants, so the Pascal
  stores the three fields (three stores, not a copy).  The cell's place
  in the pool, after the routine's first 2-byte cell and before the
  other word cells, is the pool's. }
