{ PROC1_$GET_INFO - a process's flags, CPU time and user registers.

  Image addresses:
    sau2  0x00E14F52  PROC1_$GET_INFO

  - For a process other than the current one, with an OS stack, the
    hand-written PROC1_$GET_INFO_INT reads its user registers from the
    stack; with no stack they are cleared.
  - The CPU time returned is doubled, and the cpu record's state word
    goes to the info's +0x16.

  Status stored:
    status_$ok: the information was returned
    status_$illegal_process_id: pidp is not 1..64, or has no PCB
    status_$process_not_bound: the PCB is not bound
}

procedure proc1_$get_info(in pidp: integer; out info_ret: proc1_$info_t;
                          out status_ret: status_$t);
var
  pid: pinteger;
  pcb: proc1_$pcb_ptr_t;
begin
  pid := pidp;
  status_ret.all := status_$ok;
  if (pid = 0) or else (pid > 64) then begin
    status_ret.all := status_$illegal_process_id;
    return;
  end;
  pcb := pcbs[pid];
  if pcb = nil then begin
    status_ret.all := status_$illegal_process_id;
    return;
  end;
  if not (proc1_flag_bound in pcb^.flags) then begin
    status_ret.all := status_$process_not_bound;
    return;
  end;

  info_ret.flags := pcb^.flags;
  info_ret.cpu := pcb^.cpu;
  add48(info_ret.cpu.total, pcb^.cpu.total);

  if pcb <> proc1_$current_pcb then
    if os_stack_base[pid] <> 0 then
      proc1_$get_info_int(pid, os_stack_base[pid] - 4096,
                          os_stack_base[pid], info_ret.usr,
                          info_ret.upc, info_ret.usb, info_ret.usp)
    else begin
      info_ret.usr := 0;
      info_ret.upc := 0;
      info_ret.usp := 0;
      info_ret.usb := 0;
    end;
end;
