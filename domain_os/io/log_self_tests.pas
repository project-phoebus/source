{ IO_$LOG_SELF_TESTS - log the controllers whose PROM self-test failed.

  Image addresses:
    sau9  0x3C439394  IO_$LOG_SELF_TESTS

  - For each failed entry of the configuration record's self-test list
    (cfg_ptr its address), every DCTE of that device is logged
    (log_$type_self_test): the controller's name and an empty message.

  Status stored:
    status_$ok: always
}

[section(os_init_proc, os_init_data)]
procedure io_$log_self_tests(in cfg_ptr: integer32; out status: status_$t);
type
  { The log entry: the controller's name, then a message (the entry's
    length is 10 bytes and the message's). }
  self_test_log_t = record
    name: array[1..8] of char;            { 0x00 }
    msg: varying [80] of char;            { 0x08 }
  end;
var
  cfg: os_$prom_config_ptr_t;
  k: integer32;
  d: dcte_ptr_t;
  rec: self_test_log_t;
begin
  status.all := status_$ok;
  cfg := os_$prom_config_ptr_t(cfg_ptr);
  if (cfg <> nil) and then (cfg^.self_tests <> nil) then begin
    k := 1;
    repeat
      if not cfg^.self_tests^[k].device.valid then
        exit;
      if cfg^.self_tests^[k].device.failed then begin
        d := io_$dcte_list;
        while d <> nil do begin
          if io_$match_device(cfg^.self_tests^[k].device,
                              d^.reserved_1c) then begin
            rec.name := d^.name;
            rec.msg.length := 0;
            log_$add(log_$type_self_test, rec, 10 + rec.msg.length);
          end;
          d := d^.nextp;
        end;
      end;
      k := k + 1;
    until false;
  end;
end;
