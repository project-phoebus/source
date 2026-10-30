{ disk_$map_request - map a request chain onto physical volumes.

  Image addresses:
    sau2  0x00E3CAE0  disk_$map_request

  - Each request is range-checked (unsigned), made absolute, given its
    stripe chunk's length and its cylinder, head and sector (or block
    number), and appended to its member volume's list in the map.
  - The cylinder is a 16-bit divide; the member's index into part_volx
    is not checked.

  Status stored:
    status_$ok: the chain was mapped
    status_$invalid_disk_address: an address out of range
    status_$disk_striping_not_supported: a striped block-addressed
      volume
}

procedure disk_$map_request(req: disk_$io_req_ptr_t; vol_idx: integer;
                            internal_op: pinteger;
                            var volume_map: disk_$vol_map_t;
                            out status: status_$t);
  internal;
var
  next: disk_$io_req_ptr_t;
  daddr: linteger;
  dev_flags: pinteger;
  volx: integer;
  chunk_off: integer;
  rem: pinteger;
  sectors: pinteger;
  cyl_quot: pinteger;
begin
  status.all := status_$ok;

  with disk_$dvtbl[vol_idx] do
    while req <> nil do begin
      { the address against the volume }
      next := req^.next;
      daddr := req^.daddr.daddr;
      if (daddr >= addr_start) and then
         ((daddr >= addr_end) or else (lv_start <> 0) or else
          (internal_op = disk_$req_op_write)) then begin
        status.all := status_$invalid_disk_address;
        return;
      end;

      daddr := daddr + lv_start;
      req^.header.abs_daddr := daddr;
      dev_flags := dev_info^.unit_count;
      if ((dev_flags & 16#200) <> 0) and then (part_volx[0] <> 0) then begin
        status.all := status_$disk_striping_not_supported;
        return;
      end;
      req^.flags := stripe_blk_mask + 1;

      if part_volx[0] = 0 then begin
        { one volume }
        volx := part_volx[1];
        if (dev_flags & 16#200) = 0 then begin
          req^.daddr.cyl := daddr div blocks_per_cyl;
          rem := daddr mod blocks_per_cyl;
          sectors := lshft(rem, sector_size_code);
          req^.daddr.head := sectors div sec_per_track;
          req^.daddr.sector := sectors mod sec_per_track;
        end
        else
          req^.daddr.daddr := daddr;
      end
      else begin
        { striped }
        chunk_off := stripe_blk_mask & daddr;
        daddr := rshft(daddr, stripe_blk_shift);
        rem := daddr mod blocks_per_cyl;
        sectors := lshft(rem, sector_size_code);
        req^.daddr.head := sectors div sec_per_track;
        req^.daddr.sector := sectors mod sec_per_track;
        cyl_quot := daddr div blocks_per_cyl;
        chunk_off := chunk_off + lshft(cyl_quot & stripe_vol_mask,
                                       stripe_blk_shift);
        req^.daddr.cyl := rshft(cyl_quot, stripe_vol_shift);
        chunk_off := chunk_off + 1;
        volx := part_volx[chunk_off];
      end;

      { onto the volume's list }
      if volume_map[volx].head = nil then
        volume_map[volx].head := req
      else
        volume_map[volx].tail^.next := req;
      volume_map[volx].tail := req;

      req^.next := nil;
      req^.owner_op.all := 0;
      req^.owner_op.op := internal_op;
      req := next;
    end;
end;
