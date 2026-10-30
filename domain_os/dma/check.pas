{ DMA_$CHECK - read and clear a DMA channel's completion state.

  Image addresses:
    sau2  0x00E0A3A6  DMA_$CHECK

  - The channel's status is cleared (all ones).  An error code that
    should not happen crashes the system; a channel still active is
    aborted.

  Returns:
    0: the transfer completed
    status_$bus_error_occurred_during_disk_dma_transfer: codes 9..11
    status_$floppy_is_not_2_sided: error code 16
    status_$dma_not_at_end_of_range: the channel was still active, or
      its memory transfer counter is not 0

  Status stored: none.
}

{ TODO(pascal) a bit of a register-held integer tested as a set member

  The SAU2 image tests the ERR and ACT bits of csr, the CSR byte
  zero-extended in a register, with a bit test of the register: the
  known form of the member test of a set held in a register, not of an
  `&' with a one-bit constant.  A set reading needs csr of a set type,
  but a set takes a word outside a packed record (ref 3.9.3), and a
  packed record of the channel's registers would change the conformance
  unit's record.  Not settled. }

{ TODO(pascal) 4 frame bytes unexplained (stand-in unused_10)

  The frame has 4 bytes more than the three locals and the result
  variable account for; the stand-in unused_10 holds them (the temporary of
  a `with', would fit a `with regs^ do'). }

[section(wired_proc, wired_data)]
function dma_$check(channel: integer): integer32;
  options(val_param);
var
  regs: dma_$m68450_channel_ptr_t;
  csr: integer;
  cer: integer;
  unused_10: integer32;                   { the stand-in (TODO) }
begin
  regs := addr(dma[channel]);
  csr := ord(regs^.csr);
  cer := ord(regs^.cer);
  regs^.csr := chr(16#FF);

  if (csr & m68450_csr_err) <> 0 then begin
    case cer of
      1, 2, 3, 4, 5, 6, 7, 13, 14, 15:
        crash_system(status_$disk_equipment_check);
      9, 10, 11:
        dma_$check := status_$bus_error_occurred_during_disk_dma_transfer;
      16:
        dma_$check := status_$floppy_is_not_2_sided;
      otherwise
        crash_system(status_$unknown_status_returned_by_hardware);
    end;
  end
  else if (csr & m68450_csr_act) <> 0 then begin
    regs^.ccr := chr(m68450_ccr_sab);
    regs^.csr := chr(16#FF);
    dma_$check := status_$dma_not_at_end_of_range;
  end
  else if regs^.mtc <> 0 then
    dma_$check := status_$dma_not_at_end_of_range
  else
    dma_$check := 0;
end;
