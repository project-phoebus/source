{ ring_$set_timer - load one of the controller's counters.

  Image addresses:
    sau8  0x03C81400  ring_$set_timer (module-local)
    sau9  0x3C47D000  ring_$set_timer (module-local)

  - ring8_cnt_rx_hdr, _rx_data and _b_2 restart from 16#FFFF (count
    unused); _rx_limit, _tx_hdr and _tx_end are loaded with count - 1.
  - The count's bytes go low first, each in the word's high byte.
  - Any other counter crashes the system with
    status_$network_hardware_error.

  Status stored: none.
}

procedure ring_$set_timer(count: integer; timer: integer;
                          var regs: ring8_$csr_t);
  internal;
var
  n: integer;
  lo: pinteger;
  hi: pinteger;
begin
  case timer of
    ring8_cnt_rx_hdr: begin
      regs.timer_a_ctl := 16#3000;
      regs.timer_a[0] := 16#FF00;
      regs.timer_a[0] := 16#FF00;
    end;
    ring8_cnt_rx_data: begin
      regs.timer_a_ctl := 16#7000;
      regs.timer_a[1] := 16#FF00;
      regs.timer_a[1] := 16#FF00;
    end;
    ring8_cnt_b_2: begin
      regs.timer_b_ctl := 16#B000;
      regs.timer_b[0] := 16#FF00;
      regs.timer_b[0] := 16#FF00;
    end;
    otherwise begin
      n := count - 1;
      lo := lshft(n, 8) & 16#FF00;
      hi := n & 16#FF00;
      case timer of
        ring8_cnt_rx_limit: begin
          regs.timer_a_ctl := 16#B000;
          regs.timer_a[2] := lo;
          regs.timer_a[2] := hi;
        end;
        ring8_cnt_tx_hdr: begin
          regs.timer_b_ctl := 16#3000;
          regs.timer_b[0] := lo;
          regs.timer_b[0] := hi;
        end;
        ring8_cnt_tx_end: begin
          regs.timer_b_ctl := 16#7000;
          regs.timer_b[1] := lo;
          regs.timer_b[1] := hi;
        end;
        otherwise begin
          crash_system(status_$network_hardware_error);
        end;
      end;
    end;
  end;
end;
