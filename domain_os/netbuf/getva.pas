{ NETBUF_$GETVA - map a physical page into a free slot of the window.

  Image addresses:
    sau2  0x00E0EC78  NETBUF_$GETVA

  - The first free slot is taken off the list and keeps the physical
    address; the virtual address is the slot's page in NETWORK_$BUFPOOL
    plus the address's offset in its page, mapped after the lock.
  - With no free slot the virtual address is 0.

  Status stored:
    status_$ok: the page was mapped
    status_$network_out_of_blocks: no free slot
}

procedure netbuf_$getva(ppn_shifted: integer32;
                        out va_out: univ integer32;
                        out status: status_$t);
  options(val_param);
var
  slot: integer32;
  token: pinteger;
begin
  token := ml_$spin_lock(netbuf_$spin_lock);

  slot := netbuf_$va_top;
  if slot = -1 then begin
    ml_$spin_unlock(netbuf_$spin_lock, token);
    va_out := 0;
    status.all := status_$network_out_of_blocks;
    return;
  end;

  va_out := (ppn_shifted & 16#3FF) +
            integer32(addr(network_$bufpool[slot]));
  netbuf_$va_top := netbuf_$va_slots[slot];
  netbuf_$va_slots[slot] := ppn_shifted;

  ml_$spin_unlock(netbuf_$spin_lock, token);
  status.all := status_$ok;
  mmu_$install(rshft(ppn_shifted, 10), univ_ptr(va_out), 0, 16#16);
end;
