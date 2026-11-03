{ RING_8025_$INT - a unit's interrupt routine.

  Image addresses:
    sau8  0x03C8D30E  RING_8025_$INT
    sau9  0x3C488F12  RING_8025_$INT
    sau9  0x3C48916C  the status cell (status_$network_hardware_error)

  - The routine IO_$ACQUIRE registers with the unit's DCTE.  A transfer
    the adapter asks for (bit 0 of the status byte at 4) is made by the
    host: its direction, length and physical address read a byte at a
    time from the byte at 2, then the words moved through the data word,
    a page at a time through the map page of the auxiliary area.  The
    adapter still asking for one is a crash.
  - With `ring_8025_dma_channel' the adapter makes its transfers itself:
    there is no transfer, no read of the bytes at 4 and 5, and every
    interrupt is the system interface's.
  - The byte at 5 is read; then the system interface's interrupt (bit 1
    of the status byte at 4, as read before the transfer or after it):
    by its type, the system status block is kept in the unit's copy for
    the receive status, a command, or the ring status; a command's
    completion (the transmit status, the command status of a set
    address, open or read error log command, the command block clear)
    clears the unit's command flag and wakes the waiter; the ring status
    and the adapter check flag the unit for the receive process and
    wake it.  Another type counts in the seventh statistic.  The system
    status block is released and the eventcount advanced.
  - The result is true: the interrupt was the unit's.

  Status stored: none.
}

function ring_8025_$int(dcte: integer32): boolean;
  options(val_param);
type
  { A transfer's first byte: its top bit, the direction (to the host). }
  xfer_dir_t = record
    case integer of
      1: (b: ring_8025_$byte_t);          { 0x00 }
      2: (bits: packed record             { 0x00 }
            to_host: boolean;             { bit 15 }
            unused: 0..32767;             { bits 14..0 }
          end);
  end;

  { A transfer's length, read a byte at a time. }
  xfer_len_t = record
    case integer of
      1: (all: integer);                  { 0x00 }
      2: (b: array[0..1] of ring_8025_$byte_t);  { 0x00 }
  end;

  { A transfer's physical address: a 24-bit address read a byte at a
    time, the high byte 4. }
  xfer_pa_t = record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (b: array[0..3] of ring_8025_$byte_t);  { 0x00 }
      3: (hi_w: integer;                  { 0x00 }
          lo_w: integer);                 { 0x02 }
  end;

  word_ptr_t = ^ring_8025_$word_t;
var
%if not ring_8025_dma_channel %then
  pa: xfer_pa_t;
  len: xfer_len_t;
  xdir: xfer_dir_t;
%endif
  sts: ring_8025_$sifint_t;
%if not ring_8025_dma_channel %then
  off: integer;
%endif
  ec: ec_$eventcount_ptr_t;
  u: ring_8025_$unit_ptr_t;
%if not ring_8025_dma_channel %then
  map_va: word_ptr_t;
  p: word_ptr_t;
  ppn: integer32;
  s: integer;
  t: integer;
  n: integer;
  i: integer;
%endif
  code: integer;
  rs: integer;
begin
  ec := nil;
  u := addr(ring8025_ucb[dcte_ptr_t(dcte)^.cnum]);
%if ring_8025_dma_channel %then
  { the system interface's interrupt, by its type }
  sts := u^.regs^.sifint;
%else
  with u^.regs^ do begin
    s := status_4;
    if (s & 1) <> 0 then begin
      { a transfer: its direction, length and address }
      xdir.b := pio_hdr;
      if xdir.bits.to_host then
        reset := reset ! 2
      else
        reset := reset & 16#FD;
      len.b[0] := pio_hdr;
      len.b[1] := pio_hdr;
      pa.b[0] := 4;
      pa.b[1] := pio_hdr;
      pa.b[2] := pio_hdr;
      pa.b[3] := pio_hdr;
      ppn := pa.all div 1024;
      map_va := addr(ring8025_$aux_da.map_page);
      p := word_ptr_t((pa.all & 16#3FF) + integer32(map_va));
      off := pa.lo_w & 16#3FF;
      n := 1024 - off;
      reset := reset ! 16#80;

      { the words, a page at a time }
      while len.all > 0 do begin
        mmu_$set_pmape(map_va, ring_8025_map_pmape, ppn);
        if n > len.all then
          n := len.all;
        i := 0;
        if xdir.bits.to_host then
          while i < n do begin
            p^ := pio_data;
            p := word_ptr_t(integer32(p) + 2);
            i := i + 2;
          end
        else
          while i < n do begin
            pio_data := p^;
            p := word_ptr_t(integer32(p) + 2);
            i := i + 2;
          end;
        ppn := ppn + 1;
        p := map_va;
        len.all := len.all - n;
        n := 1024;
      end;
      s := status_4;
      if (s & 1) <> 0 then
        crash_system(status_$network_hardware_error);
      reset := reset & 16#7F;
    end;
  end;

  with u^.regs^ do begin
    t := status_5;
    if (s & 2) <> 0 then begin
      { the system interface's interrupt, by its type }
      sts := sifint;
%endif
      code := sts.code;
      if code = r8025_int_rcv_status then begin
        u^.rcv_ssb := u^.ssb^;
        ec := addr(u^.rcv_wake_ec);
      end
      else if (r8025_unit_scb_busy in u^.flags)
              and then (code = r8025_int_xmit_status) then begin
        ec := addr(u^.scb_ec);
        u^.flags := u^.flags - [r8025_unit_scb_busy];
        u^.cmd_ssb := u^.ssb^;
      end
      else if (r8025_unit_scb_busy in u^.flags)
              and then (code = r8025_int_cmd_status) then begin
        if (u^.ssb^.cmd = r8025_cmd_set_funct_address)
           or else (u^.ssb^.cmd = r8025_cmd_set_group_address)
           or else (u^.ssb^.cmd = r8025_cmd_open)
           or else (u^.ssb^.cmd = r8025_cmd_read_error_log) then
          ec := addr(u^.scb_ec);
        u^.flags := u^.flags - [r8025_unit_scb_busy];
        u^.cmd_ssb := u^.ssb^;
      end
      else if (r8025_unit_scb_busy in u^.flags)
              and then (code = r8025_int_scb_clear) then begin
        ec := addr(u^.scb_ec);
        u^.flags := u^.flags - [r8025_unit_scb_busy];
      end
      else if code = r8025_int_ring_status then begin
        rs := u^.ssb^.parm[1];
        if (rs & r8025_ring_lobe_fault) <> 0 then begin
          u^.flags := u^.flags - [r8025_unit_on_ring];
          u^.flags := u^.flags + [r8025_unit_open_failed];
          ec := addr(u^.rcv_wake_ec);
        end
        else if (rs & r8025_ring_counter_ovf) <> 0 then begin
          u^.flags := u^.flags + [r8025_unit_counter_ovf];
          ec := addr(u^.rcv_wake_ec);
        end
        else if (rs & r8025_ring_removed) <> 0 then begin
          u^.flags := u^.flags + [r8025_unit_removed];
          ec := addr(u^.rcv_wake_ec);
        end
        else if (rs & r8025_ring_auto_removal) <> 0 then begin
          u^.flags := u^.flags + [r8025_unit_auto_removal];
          ec := addr(u^.rcv_wake_ec);
        end;
        u^.ring_ssb := u^.ssb^;
      end
      else if code = r8025_int_adapter_check then begin
        u^.flags := u^.flags + [r8025_unit_adapter_check];
        ec := addr(u^.rcv_wake_ec);
      end
      else
        with u^ do
          stats.other_ints := stats.other_ints + 1;
%if ring_8025_dma_channel %then
  u^.regs^.sifcmd := r8025_sifcmd_ssb_clear;
  if ec <> nil then
    ec_$advance_without_dispatch(ec^);
%else
      sifcmd := r8025_sifcmd_ssb_clear;
      if ec <> nil then
        ec_$advance_without_dispatch(ec^);
    end;
  end;
%endif
  ring_8025_$int := true;
end;
