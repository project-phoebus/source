{ REM_FILE_$RN_DO_OP - send a directory operation to the node that holds
  the directory.

  Image addresses:
    sau2  0x00E61538  REM_FILE_$RN_DO_OP

  - DIR_$DO_OP's remote path.  A listing's or an entry's outbound data
    rides in the request when it fits (290, 264 bytes in all), else as
    the packet's data.
  - The bulk reply goes to the listing's, the directory read's (at most
    1024 bytes) or the link read's buffer.

  Status stored (in the reply):
    rem_file_$send_request's status: the request was sent
    acl_$get_re_all_sids's or acl_$get_proj_list's status: the caller's
      SIDs or projects could not be had
}

procedure rem_file_$rn_do_op(var addr_info: integer32;
                             var op_buf: univ rem_file_$rn_op_buf_t;
                             base_len: integer; response_size: integer;
                             var response: univ rem_file_$response_t;
                             out received_len: integer);
  options(val_param);
const
  { DIR_$DO_OP's operation codes the routine treats apart. }
  rem_file_rn_op_dir_get_entry = 16#3C;
  rem_file_rn_op_dir_read_link = 16#3E;
  rem_file_rn_op_dir_read_dir = 16#42;
  rem_file_rn_op_dir_list = 16#58;
var
  scratch_prot: acl_prot_info_t;
  scratch_sids: acl_sid_block_t;
  local_status: status_$t;
  request_len: integer;
  bulk_len: integer;
  bulk_max: integer;
  extra_len: integer;
  packet_id: pinteger;
  extra_ptr: pkt_$bytes_ptr_t;
  bulk_ptr: pkt_$bytes_ptr_t;
begin
  acl_$get_re_all_sids(scratch_sids, op_buf.sids, scratch_prot,
                       op_buf.subsys_ids, response.status);
  if response.status.code <> 0 then
    return;

  acl_$get_proj_list(op_buf.proj_list, 8, op_buf.proj_count,
                     response.status);
  if response.status.code <> 0 then
    return;

  if acl_$in_subsys then
    op_buf.flags_20 := op_buf.flags_20 + [2];
  op_buf.hdr.magic := rem_file_req_magic;
  request_len := base_len;

  { the outbound payload }
  if op_buf.hdr.opcode = rem_file_rn_op_dir_list then begin
    if op_buf.list_data_len + base_len <= 290 then begin
      request_len := base_len + op_buf.list_data_len;
      os_$data_copy(pkt_$bytes_ptr_t(op_buf.list_data_va)^,
                    op_buf.list_inline_data, op_buf.list_data_len);
      extra_len := 0;
    end
    else begin
      extra_len := op_buf.list_data_len;
      extra_ptr := pkt_$bytes_ptr_t(op_buf.list_data_va);
    end;
  end
  else if op_buf.hdr.opcode = rem_file_rn_op_dir_get_entry then begin
    if op_buf.entry_data_len + base_len <= 264 then begin
      request_len := base_len + op_buf.entry_data_len;
      extra_ptr := addr(op_buf.bytes[op_buf.entry_dest_off]);
      os_$data_copy(pkt_$bytes_ptr_t(op_buf.entry_data_va)^,
                    extra_ptr^[16#97], op_buf.entry_data_len);
      extra_len := 0;
    end
    else begin
      extra_len := op_buf.entry_data_len;
      extra_ptr := pkt_$bytes_ptr_t(op_buf.entry_data_va);
    end;
  end
  else begin
    extra_len := 0;
    extra_ptr := addr(op_buf);
  end;

  { where the bulk reply lands }
  if op_buf.hdr.opcode = rem_file_rn_op_dir_list then begin
    bulk_ptr := pkt_$bytes_ptr_t(op_buf.list_reply_va);
    bulk_max := 1024;
  end
  else if op_buf.hdr.opcode = rem_file_rn_op_dir_read_dir then begin
    bulk_ptr := pkt_$bytes_ptr_t(op_buf.read_dir_reply_va);
    bulk_max := min(1024, op_buf.read_dir_reply_max);
  end
  else if op_buf.hdr.opcode = rem_file_rn_op_dir_read_link then begin
    bulk_ptr := pkt_$bytes_ptr_t(op_buf.entry_data_va);
    bulk_max := op_buf.entry_data_len;
  end
  else begin
    bulk_max := 0;
    bulk_ptr := addr(response);
  end;

  rem_file_$send_request(addr_info, op_buf, request_len, extra_ptr^,
                         extra_len, response, response_size, received_len,
                         bulk_ptr^, bulk_max, bulk_len, packet_id,
                         local_status);
  response.status := local_status;
end;
