# The EC subsystem in Domain Pascal

The eventcounts: the level-1 eventcounts' compiled entries and the
level-2 (EC2) eventcounts.

## Layout

The subsystem's routines lie in six map modules, three of them other
subsystems':

| map module | segments | routines | Pascal |
|------------|----------|----------|--------|
| EC2 | code in .TEXT (0x908 bytes) and OS_INIT_PROC (0x84 bytes), data in .DATA (0xEA0 bytes) | EC2_$WAIT, _$WAKEUP, _$REGISTER_EC1, _$ALLOCATE_EC1, _$GET_EC1_ADDR, _$RELEASE_EC1, _$GET_VAL; EC2_$INIT_S | `ec2.pas`, `module ec2;` |
| EC2U | code in .TEXT (0x8C bytes), no data | EC2_$INIT, _$READ, _$ADVANCE | `ec2u.pas`, `module ec2u;` |
| PROC1_ | code in WIRED_PROC (0xD88 bytes) | EC_$INIT, EC_$READ (between PROC1_$CREATE_P and PROC1_$SET_PRIORITY) | fragments `init.pas`, `read.pas` for PROC1_'s module, included by `../proc1/proc1.pas` (no section attribute: the module heading names WIRED_PROC) |
| PROC1_ASM | a D segment (0x24A4 bytes, hand-written, in WIRED_DATA) | EC_$WAIT, EC_$WAITN, EC_$ADVANCE, _$ADVANCE_ALL, _$ADVANCE_WITHOUT_DISPATCH, ADVANCE | none: hand assembly (`sau2/*.s`) |
| EC2_ASM | a D segment (0x300 bytes, hand-written data) | EC2_$WAIT_ECS | `m68k/ec2_wait_ecs.s`; `ec2_$wait_ecs` extern in `ec.ins.pas` |
| EC2_PBU | code and data | PBU_$ADVANCE_EC_INT, EC2_$PBU_ECS | `../pbu/ec2_pbu.pas` |

There is no EC_ or EC module in the map, so there is no `ec/ec.pas`;
the subsystem's two module files are `ec2.pas` and `ec2u.pas`, which
`tools/pascal_check.sh` finds by their module headings.

### EC2 (`ec2.pas`)

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| .TEXT | 0x908 bytes | EC2_$WAIT, EC2_$WAKEUP, EC2_$REGISTER_EC1, EC2_$ALLOCATE_EC1, EC2_$GET_EC1_ADDR, EC2_$RELEASE_EC1, EC2_$GET_VAL | none (the defaults) |
| OS_INIT_PROC | 0x84 bytes | EC2_$INIT_S | `[section(os_init_proc, os_init_data)]` |

Data: the map's EC2 data segment, in .DATA, 0xEA0 bytes, zero in the
image, no map symbol inside.  The .TEXT routines reach it through A5,
EC2_$INIT_S by its address; its objects are module variables:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `ec2_waiter_table_base` | array[0..224] of ec2_waiter_t (12 each) |
| +0xA8C | `ec2_$registered_ec1s` | array[0..256] of ec_$eventcount_ptr_t |
| +0xE90 | `ec2_$pbu_pending` | set of 0..31 |
| +0xE94 | `ec2_$pbu_allocated` | set of 0..31 |
| +0xE98 | `ec2_$max_registered` | linteger |
| +0xE9C | `ec2_$free_head` | pinteger |
| +0xE9E | 2 bytes: the block's rounding to 4 | |

Two cells that look like objects are not: +0xA84 is the last waiter record's
next field, and +0xE9A the low word of `ec2_$max_registered`
(EC2_$REGISTER_EC1 reads it as its search bound).

Routines: eight globals (every EC2 map symbol); none module-local, none
nested, none hand assembly.  EC2U: three globals.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| EC_$INIT | `init.pas` (PROC1_'s module) |
| EC_$READ | `read.pas` (PROC1_'s module) |
| EC_$WAIT | none: hand assembly (PROC1_ASM; `m68k/wait.s`) |
| EC_$WAITN | none: hand assembly (PROC1_ASM; it branches into proc1_$ec_waitn; `m68k/wait.s`) |
| EC_$ADVANCE | none: hand assembly (`m68k/advance.s`) |
| EC_$ADVANCE_ALL | none: hand assembly (`m68k/advance_all.s`) |
| EC_$ADVANCE_WITHOUT_DISPATCH | none: hand assembly (`m68k/advance_without_dispatch.s`) |
| ADVANCE | none: hand assembly (`m68k/advance_int.s`, with ADVANCE_INT and ADVANCE_ALL_INT) |
| EC2_$INIT_S | `ec2_init_s.pas` |
| EC2_$WAIT | `ec2_wait.pas` |
| EC2_$WAKEUP | `ec2_wakeup.pas` |
| EC2_$REGISTER_EC1 | `ec2_register_ec1.pas` |
| EC2_$ALLOCATE_EC1 | `ec2_allocate_ec1.pas` |
| EC2_$GET_EC1_ADDR | `ec2_get_ec1_addr.pas` |
| EC2_$RELEASE_EC1 | `ec2_release_ec1.pas` |
| EC2_$GET_VAL | `ec2_get_val.pas` |
| EC2_$INIT | `ec2_init.pas` (EC2U) |
| EC2_$READ | `ec2_read.pas` (EC2U) |
| EC2_$ADVANCE | `ec2_advance.pas` (EC2U) |
| (data) | the block in `ec2.pas`; EC2_$WAIT_ECS `m68k/ec2_wait_ecs.s`, extern in `ec.ins.pas`; EC2_$PBU_ECS `../pbu/ec2_pbu.pas` |

EC_$WAIT and EC_$WAITN have no frame, read their arguments off the stack
after saving two registers, load the current PCB PC-relative and call
PROC1_$EC_WAITN with a `bsr`: hand assembly in a D segment.  EC_$INIT and
EC_$READ are compiled (a frame, the slot read through A6) and lie in
PROC1_'s code segment.

Headings (`ec.ins.pas`): the EC2 and EC2U routines take the default
convention (every argument by address; EC2_$WAIT's necs a value
parameter the callee copies), but EC2_$REGISTER_EC1 (`val_param`).
EC2_$GET_EC1_ADDR is an integer32 function with `a0_return`: its one
caller, PROC2_$GET_CR_REC, parks its A0 in D0.  EC2_$ALLOCATE_EC1 and
EC2_$REGISTER_EC1 return ec2_$ptr_t in A0 (no caller parks them).
Apollo's customer ec2.ins.pas gives the headings and names of
EC2_$INIT, _$READ, _$WAIT, _$ADVANCE, its statuses and its list types.

## Insert files

- `ec.ins.pas`: Apollo's EC2 statuses and ec2_$always_ready_ec, the list
  types ec2_$ptr_list_t and ec2_$val_list_t, EC2_$WAIT_ECS, EC_$NIL_EC,
  the headings of the level-1 routines and the eleven EC2/EC2U routines.
- `fim/fim.ins.pas`: Apollo's fault_$prot_violation (16#0012000B,
  customer fault.ins.pas).
- `as/as.ins.pas`: AS_$PROTECTION (map symbol, linteger).
- Used as they are: `base`, `ml` (ML_$LOCK, _$UNLOCK), `proc1`
  (PROC1_$CURRENT, _$AS_ID), `fim` (FIM_$CLEANUP, _$RLS_CLEANUP,
  _$SIGNAL, FIM_$QUIT_EC, _$QUIT_VALUE, fault_$cleanup_set),
  `pbu/pbu.ins.pas` (pbu_$ec_entry_t, EC2_$PBU_ECS, the PBU numbers).
  pbu_$ec_entry_t's word at +0xE, reserved1, is the record's waiter
  count for EC2 (counted up and down by EC2_$WAIT, tested by
  EC2_$ALLOCATE_EC1 and _$RELEASE_EC1); the shared type is not renamed.

## Open items

### TODO(pascal)

- `ec2_init_s.pas`: four frame bytes (stand-in unused_8).
- `ec2_wakeup.pas`: four frame bytes (stand-in unused_2c).
- `ec2_init.pas`: four frame bytes of EC2_$INIT and EC2_$ADVANCE
  (stand-ins unused_4).
- `ec2_wait.pas`: the frame against the locals (eight compiler
  temporaries, the arrays' bounds, 26 open bytes too few for the
  register-held locals).
