# The BAT subsystem in Domain Pascal

The block allocation table (each logical volume's bitmap of free disk
blocks, its partitions and their VTOCE chains).

## Layout

One module, `bat.pas`, `module bat_;` (the map segments' name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| .TEXT | 0xE60 bytes | BAT_$ALLOC_FM .. BAT_$GET_BAT_STEP | none (the default) |

Data: the map's BAT_ data segment, 0xD54 bytes in .DATA (the default),
through A5 in every routine, all zero in the image:

| offset | variable | type |
|--------|----------|------|
| +0x000 | BAT_DATA (`define`d; a global though `$`-less) | array[1..6] of bat_$volume_t (0x234 bytes each) |
| +0xD38 | `bat_$cached_buffer` | bat_$bitmap_ptr_t |
| +0xD3C | `bat_$cached_block` | linteger |
| +0xD40 | `bat_$volume_flags` | array[1..6] of boolean |
| +0xD46 | `unused_d46` | integer, a stand-in: nothing addresses it (bat.pas) |
| +0xD48 | `bat_$mounted` | array[1..6] of boolean |
| +0xD4E | `bat_$cached_dirty` | integer |
| +0xD50 | `bat_$cached_vol` | integer |
| +0xD52 | 2 bytes: the block's rounding to 4 | |

Routines: eleven globals (every map symbol), none module-local, none
nested, none hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| BAT_$ALLOC_FM | `alloc_fm.pas` |
| BAT_$ADD_PART_VTOCE | `add_part_vtoce.pas` |
| BAT_$ALLOC_VTOCE | `alloc_vtoce.pas` |
| BAT_$ALLOCATE | `allocate.pas` |
| BAT_$FREE | `free.pas` |
| BAT_$MOUNT | `mount.pas` |
| BAT_$DISMOUNT | `dismount.pas` |
| BAT_$N_FREE | `n_free.pas` |
| BAT_$RESERVE | `reserve.pas` |
| BAT_$CANCEL | `cancel.pas` |
| BAT_$GET_BAT_STEP | `get_bat_step.pas` |
| (data) | the block in `bat.pas`; BAT_$UID is UID_LIST's (`bat.ins.pas`, extern) |

## Insert files

- `bat.ins.pas` (VOLX's, reviewed in C1; its constant and its
  BAT_$N_FREE heading unchanged): the statuses bat_$invalid_block and
  bat_$error, ml_lock_bat, the DBUF flags words, the VTOCE constants;
  the types of the volume record, nested as the image copies them
  (bat_$hdr_t, bat_$ptab_t, bat_$partition_t), the label
  (bat_$label_t), the bitmap and VTOCE block views; BAT_DATA and
  BAT_$UID extern; the headings of the other ten routines.
- `disk/disk.ins.pas`: status_$disk_is_full and
  status_$disk_needs_salvaging (BAT manager codes); DISK_$DVTBL, the
  volume descriptors from volume 1 (ten).
- `time/time.ins.pas`: TIME_$BOOT_TIME.
- `uid/uid.ins.pas`: LV_LABEL_$UID.
- Used as they are: `ec/ec.ins.pas`, `ml/ml.ins.pas`,
  `node/node.ins.pas` (NODE_$ME), `dbuf/dbuf.ins.pas` (DBUF_$GET_BLOCK,
  DBUF_$SET_BUFF, dbuf_get_no_read), `fm/fm.ins.pas` and
  `vtoc/vtoc.ins.pas` (VTOC_$UID), `pkt/pkt.ins.pas` and
  `network/network.ins.pas` (NETWORK_$REALLY_DISKLESS).

## The record views

- The volume record's first 0x20 bytes and its next 0x20C bytes are
  copied as whole records (BAT_$MOUNT, BAT_$DISMOUNT) and reached
  through `with` temporaries of their own: the Pascal has the record
  nested, `hdr` and `ptab`.  The label likewise (`bat_hdr`, `bat_ptab`).
- The partition record's longword at +4 is masked and merged as one
  longword (BAT_$ADD_PART_VTOCE) and its first byte read alone: a variant
  record, the byte named `state` (a field `status` would hide the
  routines' status parameters inside `with`).
- The header's step pair at +0x12 is one longword to BAT_$ALLOCATE and
  BAT_$MOUNT: a variant `step_long`.
- The map names the volume array BAT_DATA, from volume 1 (the lower
  bound folded into the displacements).
- BAT_$ALLOC_FM's hint and block are one variable in the image (one
  slot, pushed by value and by address); BAT_$ALLOC_VTOCE copies its
  hint into a local of its own at entry and pushes that.
- BAT_$MOUNT and BAT_$DISMOUNT hold the label's address in an integer
  local, `label_addr` (`label` is a reserved word), and avoid a local
  `current_time`, which the label's field of that name would hide
  inside `with` (MOUNT's local is `clockh`; DISMOUNT has none, the image
  keeping one load).

## Open items

### TODO(pascal)

- `n_free.pas`: the volume index compared unsigned against the reviewed
  integer heading; changing the heading to pinteger would touch
  VOLX_$GET_INFO's call by address.
