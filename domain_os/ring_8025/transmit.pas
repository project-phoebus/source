{ ring_8025_transmit - send a frame from a list of pieces.

  Image addresses:
    sau8  0x03C8A00E  ring_8025_transmit
    sau9  0x3C485C12  ring_8025_transmit

  - The memory control register's bit 8 is changed first.
  - The first three pieces go to the current transmit list's data
    descriptors; with more than three the list does not end the frame
    and the rest go to the next list's.  The adapter is told the list is
    valid and its completion is awaited for 5 ticks.
  - A completion that is not seen halts and restarts the transmitter.
  - A frame recognized but not copied, a transmit error or any other
    frame status is sent again, after 50 ms, at most 10 times in all.
    A frame no station recognized counts as transmitted (and as
    unrecognized unless it went to this node).
  - fstat returns the frame status of the last try.  At the end the unit
    is moved past the frame's lists.

  Status stored:
    ring_8025_wait_scb's status: the last try's completion was or was
      not seen
}

procedure ring_8025_transmit(u: ring_8025_$unit_ptr_t; frame_size: integer;
                             in pieces: univ ring_8025_$xmit_pieces_t;
                             count: integer; in dest: ring_8025_$addr_t;
                             out fstat: integer; out status: status_$t);
  internal;
var
  clock: time_$clock_t;
  xl: ring_8025_$list_ptr_t;
  nl: ring_8025_$list_ptr_t;
  l: ring_8025_$list_ptr_t;
  n: integer;
  tries: integer;
  i: integer;
begin
  n := r8025_list_data;
  tries := 10;
  if n > count then
    n := count;
  repeat
    mmu_$mcr_change(8);

    { the pieces into the list, and into the next one past three }
    xl := u^.xmit_list;
    xl^.frame_size := frame_size;
    for i := 1 to n do begin
      xl^.data[i].pa := pieces[i].pa;
      xl^.data[i].cnt.count := pieces[i].cnt.len;
      xl^.data[i].cnt.mark := true;
    end;
    xl^.data[n].cnt.mark := false;
    if count > r8025_list_data then begin
      with u^.xmit_list^ do begin
        cstat := [r8025_cstat_valid, r8025_cstat_start_frame,
                  r8025_cstat_frame_int];
        nl := next;
      end;
      nl^.cstat := [r8025_cstat_end_frame];
      for i := 1 to count - n do begin
        nl^.data[i].pa := pieces[r8025_list_data + i].pa;
        nl^.data[i].cnt.count := pieces[r8025_list_data + i].cnt.len;
        nl^.data[i].cnt.mark := true;
      end;
      nl^.data[count - n].cnt.mark := false;
    end
    else
      u^.xmit_list^.cstat := [r8025_cstat_valid, r8025_cstat_start_frame,
                              r8025_cstat_end_frame, r8025_cstat_frame_int];

    { hand the list to the adapter, await the completion }
    u^.flags := u^.flags + [r8025_unit_scb_busy];
    u^.scb_wait_val := ec_$read(u^.scb_ec) + 1;
    u^.regs^.sifcmd := r8025_sifcmd_xmit_valid;
    ring_8025_wait_scb(u, 5, status);
    l := u^.xmit_list;
    fstat := l^.fstat;
    if status.all = status_$ok then begin
      if not (r8025_cstat_xmit_error in l^.cstat) then
        case l^.fstat of
          r8025_fs_copied: begin
            u^.stats.xmit_ok := u^.stats.xmit_ok + 1;
            exit;
          end;
          r8025_fs_not_copied: begin
            u^.stats.xmit_not_copied := u^.stats.xmit_not_copied + 1;
          end;
          r8025_fs_none: begin
            if (dest.high = r8025_addr_high) and then (dest.low = node_$me)
            then
              u^.stats.xmit_ok := u^.stats.xmit_ok + 1
            else begin
              u^.stats.xmit_ok := u^.stats.xmit_ok + 1;
              u^.stats.xmit_unrecognized := u^.stats.xmit_unrecognized + 1;
            end;
            exit;
          end;
          otherwise begin
            u^.stats.xmit_errors := u^.stats.xmit_errors + 1;
          end;
        end
      else
        u^.stats.xmit_errors := u^.stats.xmit_errors + 1;
    end
    else begin
      ring_8025_xmit_halt(u);
      ring_8025_start_xmit(u);
      u^.stats.cmd_failures := u^.stats.cmd_failures + 1;
      return;
    end;

    { again, on the next list, after 50 ms }
    tries := tries - 1;
    if tries = 0 then
      exit;
    clock.high := 0;
    clock.low := 12500;
    time_$wait(time_$relative, clock, status);
    u^.xmit_list := u^.xmit_list^.next;
  until false;

  { past the frame's one or two lists }
  if r8025_cstat_end_frame in l^.cstat then
    u^.xmit_list := l^.next
  else
    u^.xmit_list := l^.next^.next;
end;
