{ disk_$io_error - record and log a failed transfer.

  Image addresses:
    sau2  0x00E3C14C  disk_$io_error

  - A request never issued (status -1) or with an invalid address is not
    logged.
  - Otherwise DISK_$ERROR_INFO gets the time, the address (a linear
    block number), the device ids, the geometry, the headers, the
    volume, the page and the status.
  - LOG_$ADD gets a 16-byte record.
  - A striped volume on a drive addressed by block number crashes the
    system.

  Status stored: none.
}

procedure disk_$io_error(vol_idx: integer; in req: disk_$io_req_t;
                         in info: disk_$info_t);
  internal;
type
  devid_t = packed record
    case integer of
      1: (all: pinteger);
      2: (dev_type: 0..31;                { bits 15..11 }
          ctlr: 0..7;                     { bits 10..8 }
          unit: 0..15;                    { bits 7..4 }
          unused_3_0: 0..15);             { bits 3..0 }
  end;
  log_t = record
    daddr: linteger;                      { 0x00 }
    block: linteger;                      { 0x04 }
    status: status_$t;                    { 0x08 }
    pv_devid: devid_t;                    { 0x0C }
    vol_devid: devid_t;                   { 0x0E }
  end;
  vol_ptr_t = ^disk_$volume_t;
var
  log: log_t;
  vol_devid: devid_t;
  pv_devid: devid_t;
  pv_volx: pinteger;
  part_off: pinteger;
  pv: vol_ptr_t;
  blk_in_cyl: linteger;
  cyl_blocks: linteger;
  daddr: linteger;
  block: linteger;
begin
  if (req.status.all = -1) or else
     (req.status.all = status_$invalid_disk_address) then
    return;

  pv_volx := disk_$dvtbl[vol_idx].part_volx[1];
  part_off := 0;
  if vol_idx <> pv_volx then
    part_off := disk_$dvtbl[vol_idx].num_parts - 1;
  pv := addr(disk_$dvtbl[pv_volx]);

  if (pv^.dev_info^.unit_count & 16#200) = 0 then begin
    { cylinder, head and sector back to a block }
    blk_in_cyl := rshft(req.daddr.head * pv^.sec_per_track
                        + req.daddr.sector, pv^.sector_size_code);
    cyl_blocks := req.daddr.cyl * pv^.blocks_per_cyl + blk_in_cyl;
    daddr := (lshft(req.daddr.cyl, pv^.stripe_vol_shift)
              + rshft(part_off, pv^.stripe_blk_shift))
             * pv^.blocks_per_cyl + blk_in_cyl;
    daddr := lshft(daddr, pv^.stripe_blk_shift)
             + (part_off & pv^.stripe_blk_mask);

    { the two device ids }
    vol_devid.all := 0;
    vol_devid.dev_type := disk_$dvtbl[vol_idx].dev_info^.device_type;
    vol_devid.ctlr := disk_$dvtbl[vol_idx].dev_info^.controller;
    vol_devid.unit := disk_$dvtbl[vol_idx].dev_unit;
    pv_devid.all := 0;
    pv_devid.dev_type := pv^.dev_info^.device_type;
    pv_devid.ctlr := pv^.dev_info^.controller;
    pv_devid.unit := pv^.dev_unit;

    { the error record }
    disk_$error_info.timestamp := time_$current_clockh;
    disk_$error_info.daddr := daddr;
    disk_$error_info.geometry.sec_per_track := pv^.sec_per_track;
    disk_$error_info.geometry.num_heads := pv^.num_heads;
    disk_$error_info.info := info;
    disk_$error_info.header := req.header;
    disk_$error_info.vol_idx := vol_idx;
    disk_$error_info.ppn := req.ppn;
    disk_$error_info.status := req.status;

    log.daddr := daddr;
    log.block := cyl_blocks;
  end
  else begin
    { a block-addressed drive cannot stripe }
    if pv^.part_volx[0] <> 0 then begin
      crash_system(status_$disk_striping_not_supported);
      return;
    end;

    pv_devid.all := 0;
    pv_devid.dev_type := pv^.dev_info^.device_type;
    pv_devid.ctlr := pv^.dev_info^.controller;
    pv_devid.unit := pv^.dev_unit;

    daddr := req.daddr.daddr;
    disk_$error_info.timestamp := time_$current_clockh;
    disk_$error_info.daddr := daddr;
    disk_$error_info.vol_idx := vol_idx;
    disk_$error_info.ppn := req.ppn;
    disk_$error_info.status := req.status;
    block := daddr;
    vol_devid := pv_devid;
    log.daddr := daddr;
    log.block := block;
  end;

  log.status := req.status;
  log.pv_devid := pv_devid;
  log.vol_devid := vol_devid;
  log_$add(12, log, 16);
end;
