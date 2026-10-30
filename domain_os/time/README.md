# The TIME subsystem in Domain Pascal

The clocks, the time queues, the timed waits and the interval timers.

## Layout

Three compiled map modules, each its own module file, and the hand
assembly of TIME_ASM (no Pascal).  The checker finds every module file
by its heading (`tools/pascal_check.sh`).

| module file | heading | code | data |
|-------------|---------|------|------|
| `time.pas` | `module time_, wired_proc, wired_data;` | WIRED_PROC (0x7A8 bytes): TIMER_$INIT (`../timer/init.pas`) .. TIME_$GET_ADJUST; OS_INIT_PROC (0xE4 bytes): TIME_$INIT, `[section(os_init_proc, os_init_data)]` | TIME_ (0x1628 bytes), WIRED_DATA: the module variables below |
| `time_q_.pas` | `module time_q_;` | WIRED_PROC (0x4F8 bytes), each routine `[section(wired_proc, wired_data)]` | none |
| `time_unwired.pas` | `module time_unwired;` | .TEXT (0x6C0 bytes) | none |

TIME_'s block (all zero in the image):

| offset | variable | type |
|--------|----------|------|
| +0x0000 | TIME_$CPU_LIMIT_DB (`define`d, map symbol) | time_$db_t: array[0..57] of 0x1C-byte records |
| +0x0658 | TIME_$ITIMER_DB (`define`d) | array[0..1] of time_$db_t (real, virtual) |
| +0x1308 | TIME_$VTQ (`define`d) | array[1..64] of time_$queue_t |
| +0x1608 | TIME_$RTEQ (`define`d) | time_$queue_t |
| +0x1614 | `zero_interval` | time_$clock_t |
| +0x161A | 2 bytes: the next pointer's alignment | |
| +0x161C | `fast_clock_ec_handle` | ec2_$ptr_t |
| +0x1620 | `clock_ec_handle` | ec2_$ptr_t |
| +0x1624 | TIME_$SYS_FREQ (`define`d; no reference in the image) | integer32 |

`time.pas` includes `../timer/init.pas` first in its WIRED_PROC
segment.

Routines: 27 compiled globals (every TIME_, TIME_Q_ and TIME_UNWIRED
map symbol but TIMER_$INIT, which is timer/'s), 7 module-local
(`internal`, no map symbol; lower-case names), none
nested.  TIME_$RTE_INT and TIME_$VT_INT are functions returning a
pointer in A0, nil, which PROC1_$INT_EXIT's deferred-interrupt loop
reads.  No caller copies an A0 result to D0.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| (TIMER_$INIT) | `../timer/init.pas` |
| TIME_$RTE_INT | `rte_int.pas` |
| TIME_$VT_INT | `vt_int.pas` |
| TIME_$ADVANCE_CALLBACK | `advance_callback.pas` |
| TIME_$ADVANCE | `advance.pas` |
| TIME_$CANCEL | `cancel.pas` |
| TIME_$WAIT | `wait.pas` |
| TIME_$WAIT2 | `wait2.pas` |
| TIME_$GET_EC | `get_ec.pas` |
| TIME_$SET_TIME_OF_DAY | `set_time_of_day.pas` |
| TIME_$ADJUST_TIME_OF_DAY | `adjust_time_of_day.pas` |
| TIME_$GET_ADJUST | `get_adjust.pas` |
| time_$q_insert_sorted | `q_insert_sorted.pas` |
| time_$q_remove_internal | `q_remove_internal.pas` |
| time_$q_setup_timer | `q_setup_timer.pas` |
| TIME_$Q_INIT | `q_init.pas` (empty procedure) |
| TIME_$Q_INIT_QUEUE | `q_init_queue.pas` |
| TIME_$Q_FLUSH_QUEUE | `q_flush_queue.pas` |
| TIME_$Q_REENTER_ELEM | `q_reenter_elem.pas` |
| TIME_$Q_ENTER_ELEM | `q_enter_elem.pas` |
| TIME_$Q_ADD_CALLBACK | `q_add_callback.pas` |
| TIME_$Q_REMOVE_ELEM | `q_remove_elem.pas` |
| TIME_$Q_SCAN_QUEUE | `q_scan_queue.pas` |
| TIME_$READ_CAL, time_$read_cal_delay, time_$read_cal_delay_20 | none: hand assembly (TIME_ASM; `m68k/time_asm.s`, with the body time_$read_cal_body) |
| TIME_$VT_TIMER | none: hand assembly (TIME_ASM, register arguments; `m68k/time_asm.s`) |
| TIME_$WRT_VT_TIMER | none: hand assembly (`m68k/time_asm.s`) |
| TIME_$WRT_TIMER | none: hand assembly (TIME_ASM; `m68k/time_asm.s`) |
| TIME_$CLOCK | none: hand assembly (TIME_ASM; `m68k/time_asm.s`) |
| TIME_$ABS_CLOCK | none: hand assembly (TIME_ASM; `m68k/time_asm.s`) |
| TIME_$GET_TIME_OF_DAY | none: hand assembly (TIME_ASM; `m68k/time_asm.s`) |
| TIME_$SET_VECTOR | none: hand assembly (TIME_ASM; `m68k/time_asm.s`) |
| TIME_$TIMER_HANDLER | none: hand assembly (`m68k/timer_handler.s`) |
| (ADD48, SUB48) | none: hand assembly (TIME_ASM, the code segment; `m68k/add48.s`) |
| TIME_$INIT | `init.pas` |
| TIME_$SET_ITIMER_REAL_CALLBACK | `set_itimer_real_callback.pas` |
| TIME_$SET_ITIMER_VIRT_CALLBACK | `set_itimer_virt_callback.pas` |
| TIME_$SET_CPU_LIMIT_CALLBACK | `set_cpu_limit_callback.pas` |
| TIME_$RELEASE | `release.pas` |
| time_$clock_to_itimer | `clock_to_itimer.pas` |
| time_$itimer_to_clock | `itimer_to_clock.pas` |
| time_$get_itimer_internal | `get_itimer_internal.pas` |
| time_$set_itimer_internal | `set_itimer_internal.pas` |
| TIME_$SET_ITIMER | `set_itimer.pas` |
| TIME_$GET_ITIMER | `get_itimer.pas` |
| TIME_$SET_CPU_LIMIT | `set_cpu_limit.pas` |
| (data) | the block in `time.pas`; TIME_ASM's variables extern in `time.ins.pas` |

Why TIME_ASM is hand assembly: its code lies in a
data segment (the map's TIME_ASM data segment), reads its arguments off
the stack with no frame (TIME_$WRT_TIMER), takes them in registers
(TIME_$WRT_VT_TIMER), jumps into shared code (TIME_$READ_CAL) and uses
an encoding of a compare with an immediate that compiled code does not;
the TIME_ASM code segment holds ADD48 and SUB48 (`_ASM').

Headings (`time.ins.pas`, in map order): the user-callable routines
(TIME_$GET_EC, _$SET_TIME_OF_DAY, _$ADJUST_TIME_OF_DAY, _$SET_ITIMER,
_$GET_ITIMER, _$SET_CPU_LIMIT; SVC cells) and the queue routines with no
value parameter take the default convention; TIME_$CANCEL,
TIME_$Q_INIT_QUEUE, _$Q_REENTER_ELEM, _$Q_ADD_CALLBACK and the two
deferred-interrupt routines `val_param'; the internal ones `internal'.

## Insert files

- `time.ins.pas` (in map order): Apollo's statuses, time_$timeval_t
  (Apollo's base.ins.pas), the element pointer and callback types, the
  database record and array, the TIME_UNWIRED callback datum; TIME_'s
  map-symbol variables (extern; defined by `time.pas`) and TIME_ASM's
  (IN_VT_INT, IN_RT_INT, the two clock eventcounts, the low clock words,
  the time of day, the tick, the skew, the delta); the headings of every
  compiled global and of TIME_ASM's routines with compiled callers.  Its
  includers still need only base and ec before it.  TIME_$WAIT's first
  parameter is `in' (below).
- `di/di.ins.pas`: di_$q_elem_t and DI_$INIT_Q_ELEM's heading.
- `proc1/proc1.ins.pas`: PROC1_$VT_INT, PROC1_$SET_VT, PROC1_$GET_CPUT8.
- `proc2/proc2.ins.pas`: PROC2_$SIGNAL_OS's param is `univ' (the
  callbacks pass literal statuses).
- `cal/cal.ins.pas`: CAL_$WRITE_CALENDAR.
- Used as they are: `ec`, `ml`, `misc/crash_system`, `fim` (the quit
  eventcounts and values), `dxm` (DXM_$ADD_CALLBACK, the two queues),
  `timer`.

## Open items

### Forms the image settles

- TIME_$RTE_INT and TIME_$VT_INT are functions whose nil result in A0
  PROC1_$INT_EXIT reads.
- The two bytes the callers of time_$get_itimer_internal and
  time_$set_itimer_internal leave above the arguments are the alignment
  pad.
- time_$clock_to_itimer and time_$itimer_to_clock are functions
  returning a clock through a hidden result address,
  called inside other calls' argument lists.
- TIME_$CURRENT_TIME's second longword (the microseconds) is not a map
  symbol of its own.
- TIME_$GET_EC's key: Apollo's customer time_$key_t has one value; the
  kernel accepts 1 too (the fast clock).
- TIME_$WAIT's first argument is read after the first statement (an
  `in' parameter and a local `dtype'), where TIME_$WAIT2's is a value
  parameter copied at entry.

### TODO(pascal)

- `q_setup_timer.pas`: 4 frame bytes no declared local explains.
- `q_scan_queue.pas`: 8 frame bytes no declared local explains.
- `init.pas`: 6 frame bytes below the loop index's slot.
- `set_itimer_internal.pas`: PROC1_$AS_ID widened with zeros for the
  callbacks' datum (here and in TIME_$SET_CPU_LIMIT), against
  `proc1.ins.pas`'s `integer'.

The SAU2 frames of TIME_$WAIT,
TIME_$SET_TIME_OF_DAY, TIME_$ADJUST_TIME_OF_DAY, TIME_$SET_CPU_LIMIT,
time_$set_itimer_internal, time_$q_insert_sorted and the small routines
are explained to the byte by their locals' declaration order, the
8-byte places of the clocks and 8-alignment of the larger
records.

## Named dispatch codes

time/time.ins.pas names TIME_$GET_EC's keys: `time_$clockh_key` (Apollo's
time.ins.pas time_$key_t enumerator) and `time_$fast_clock_key`.
