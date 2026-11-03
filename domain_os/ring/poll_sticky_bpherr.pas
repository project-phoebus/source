{ RING_$POLL_STICKY_BPHERR - read and clear the ring's sticky biphase error.

  Image addresses:
    sau2  0x00E76290  RING_$POLL_STICKY_BPHERR
    sau4  0x0F883B1C  RING_$POLL_STICKY_BPHERR
    sau8  0x03C82B20  RING_$POLL_STICKY_BPHERR
    sau9  0x3C47E712  RING_$POLL_STICKY_BPHERR

  - When the controller's DCTE status is clear, the result is whether
    the mode word has both bits 13 and 12, and the mode word is cleared;
    else the result is false and the word left alone.
  - With `ring8_controller' the controller's status word is read
    instead: while its bit 15 is clear, an error among bits 8..10 is
    counted in the unit's xmit_modem, bits 8 and 9 each in
    RING_$XMIT_ESB, and bit 8 makes the result true; the errors are then
    cleared.
  - With `ring_board_dma': transmit status bit 10 while receive status
    bit 14 is set; nothing is cleared.

  Status stored: none.
}

function ring_$poll_sticky_bpherr(in dcte: dcte_ptr_t): boolean;
var
%if ring8_controller %then
  csr: ring8_$csr_ptr_t;
  err: ring8_$csr_set_t;
%else
  regs: ring_$regs_ptr_t;
%endif
begin
%if ring8_controller %then
  ring_$poll_sticky_bpherr := false;
  if dcte^.cstatus.all = 0 then begin
    csr := ring8_$csr_ptr_t(
             ring8_$io_desc_ptr_t(dcte^.disk_dinit)^.csr.va);
    err := csr^.status;
    if not (15 in err) then
      if err * [8..10] <> [] then begin
        if 8 in err then begin
          ring_$poll_sticky_bpherr := true;
          ring_$xmit_esb := ring_$xmit_esb + 1;
        end;
        if 9 in err then
          ring_$xmit_esb := ring_$xmit_esb + 1;
        with ring_$data[dcte^.cnum] do
          xmit_modem := xmit_modem + 1;
      end;
    csr^.clear_error := 1;
  end;
%else
  with dcte^ do begin
    if cstatus.all <> 0 then begin
      ring_$poll_sticky_bpherr := false;
      return;
    end;
    regs := disk_dinit;
%if ring_board_dma %then
    if 14 in regs^.rx_status then
      ring_$poll_sticky_bpherr := 10 in regs^.tx_status
    else
      ring_$poll_sticky_bpherr := false;
%else
    if 13 in regs^.mode then
      ring_$poll_sticky_bpherr := 12 in regs^.mode
    else
      ring_$poll_sticky_bpherr := false;
    regs^.mode := [];
%endif
  end;
%endif
end;
