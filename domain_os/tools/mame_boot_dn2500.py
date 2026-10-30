#!/usr/bin/env python3
"""mame_boot_dn2500.py - run an SAU9 RFC image on MAME's DN2500 without sysboot.

The MD9 PROM of the DN2500 machine (a local addition to MAME) does not boot
from a disk yet (its SCSI chip test fails), so this harness takes the PROM
through its power-up self-tests to
its `>' prompt on the serial console and then does what sysboot would have
done: it places the RFC image in RAM at its load address (0x4002400, the
whole file), builds the frame COLD_START
pops and jumps to the image's start address with the MMU off (the PROM runs
with TC = 0 at its prompt).  MAME runs headless with the Lua script
tools/mame_boot_dn2500.lua.

The console: with no monitor the PROM searches the serial lines for a
terminal (a CR at 9600 baud) and uses SIO1.  MAME's SIO1 is a null modem
whose bitbanger connects to a TCP socket this script listens on; the
script sends CRs until the PROM answers, answers `n' to "Do you wish to
continue with the system BOOT process", and logs everything the line
carries (the PROM's and later the kernel's console output) to
<out>/console.txt.

The frame COLD pops (sysboot's exec helper, sysboot 0x13FE96, on the PROM
machine-id bit 4 path, 0x13F692): a return address, D1 (0: the boot
device word), D2 (the boot flags in the low word, --flags, sysboot sets
bit 3), A1 (0: no diskless block), a word, A2 (the PROM's configuration
record, 0x040008A8: ROM 0x18888, the PROM's a5 0x18978 less 240).  The
record's +4 is COLD's memory limit; at the prompt it is still 0 (the
PROM's BOOT path fills it, not found yet), so the harness stores the RAM
size there (--mem-limit), the size the PROM's MEM command reports.

The calendar: MAME starts the MC146818 at the host's date in BCD, while
Apollo's CALENDAR program leaves it in binary (CAL_$WRITE_CALENDAR,
cal/sau9/write_calendar.s), and the host's date is past the end of the
48-bit system clock (2015).  So at entry the harness writes --calendar
into the chip in binary, the way CAL_$WRITE_CALENDAR does.  With
--clean-volume it also clears the --hard image's salvage flag (the LV
label, block 1, byte 0xCE: the kernel marks the volume dirty at mount and
a run never dismounts) and sets the label's last valid time (0xE6) to 12
hours before --calendar, so CAL_$VERIFY accepts the calendar in any time
zone.

    tools/mame_boot_dn2500.py                       # our dist/sau9/domain_os
    tools/mame_boot_dn2500.py --image ../sr10.2-install/install/ri.apollo.os.v.10.2/sau9/domain_os \\
        --map ../sr10.2-install/install/ri.apollo.os.v.10.2/sau9/domain_os.map   # the oracle

Everything MAME writes (error.log, cfg) lives under <repo>/tmp/dn2500
(--work-dir), the calendar's nvram, fresh each run, under the run's
--out-dir; the MAME tree is only read (binary).
"""
import argparse
import datetime
import shutil
import os
import re
import socket
import subprocess
import sys
import threading
import time

STOP_SYMBOLS = ['CRASH_SYSTEM', 'FIM_$CRASH', 'FIM_$BUS_ERR', 'FIM_$UII', 'FIM_$PRIV_VIOL',
                'FIM_$FLINE', 'FIM_$SPURIOUS_INT', 'FIM_$PARITY_TRAP', 'FIM_$NMI']
PROGRESS_SYMBOLS = ['OS_$COLD_START', 'OS_$INIT', 'MMU_$INIT', 'MMAP_$INIT', 'TIME_$INIT',
                    'PROC1_$INIT', 'PEB_$INIT', 'IO_$INIT', 'SYSBUS_$INIT', 'TIMER_$INIT',
                    'SIO16550_$INIT', 'SCSI_$INIT', 'WIN_SCSI_$DINIT', 'MONO9_$IOINIT',
                    'FIM_$INIT', 'AST_$INIT', 'AREA_$INIT', 'MST_$INIT', 'DISK_$INIT',
                    'NETWORK_$INIT', 'FILE_$INIT', 'VTOC_$INIT', 'OS_$START_PROC2', 'CAL_$INIT']
PROM_RECORD = 0x040008A8


def read_syms(args):
    syms = {}
    if args.map:
        for line in open(args.map, errors='replace'):
            m = re.match(r'^\s*(?:[A-Z]\d*\s+)?([0-9A-F]{6,8})\s+([A-Z_$][\w$]*)', line)
            if m and m.group(2) not in ('size', 'loaded'):
                syms.setdefault(m.group(2), int(m.group(1), 16))
    else:
        nm = subprocess.check_output(['m68k-elf-nm', args.elf]).decode()
        for line in nm.splitlines():
            p = line.split()
            if len(p) == 3 and p[1] in 'TtDdBb':
                syms.setdefault(p[2], int(p[0], 16))
    return syms


def console_server(port, out_path, answers, done, log, prompt_flag, send_cr=True, script=(), finish=None):
    """the terminal: CRs until the PROM speaks (unless send_cr is off: the
    keyboard is then the console), then the canned answers, or the script's
    steps in order: ('expect', text) waits for text since the last step,
    ('send', text) sends it, ('sleep', seconds) waits; finish is (text,
    path): once text has been seen, path is created (the Lua then ends the
    run)"""
    ls = socket.socket()
    ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    ls.bind(('127.0.0.1', port))
    ls.listen(1)
    ls.settimeout(120)
    try:
        s, _ = ls.accept()
    except socket.timeout:
        log.append('console: MAME never connected')
        return
    s.settimeout(0.25)
    out = open(out_path, 'wb')
    text, got, last_cr = '', False, 0.0
    pending = [] if script else list(answers)
    steps, since, wake = list(script), '', 0.0
    seen = ''
    while not done.is_set():
        try:
            d = s.recv(4096)
            if not d:
                break
            out.write(d)
            out.flush()
            got = True
            text += d.decode('latin-1')
            text = text[-4000:]
            since = (since + d.decode('latin-1'))[-4000:]
            seen = (seen + d.decode('latin-1'))[-4000:]
        except socket.timeout:
            pass
        except OSError:
            break
        now = time.time()
        if send_cr and not got and now - last_cr > 1.0:
            s.send(b'\r')
            last_cr = now
        while steps and now >= wake:
            kind, arg = steps[0]
            if kind == 'expect':
                if arg not in since:
                    break
                since = since[since.index(arg) + len(arg):]
            elif kind == 'send':
                s.send(arg.encode('latin-1'))
            else:
                wake = now + float(arg)
            steps.pop(0)
        if finish and finish[0] in seen:
            open(finish[1], 'w').close()
            finish = None
        for i, (expect, reply) in enumerate(pending):
            if expect in text:
                s.send(reply.encode())
                text = ''
                pending.pop(i)
                break
        if prompt_flag and '\n>' in text:
            open(prompt_flag, 'w').close()
            prompt_flag = None
    out.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    repo = os.path.dirname(here)
    ap.add_argument('--image', default=os.path.join(here, 'dist/sau9/domain_os'))
    ap.add_argument('--elf', default=os.path.join(here, 'build/sau9/domain_os.elf'))
    ap.add_argument('--map', default=None, help='take symbols from this SAU9 link map instead of --elf (the original image)')
    ap.add_argument('--mame-bin', default=os.path.join(repo, 'tmp/mame-dn2500/phoebus'))
    ap.add_argument('--rompath', default=os.path.join(repo, 'tmp/dn2500/roms'))
    ap.add_argument('--work-dir', default=os.path.join(repo, 'tmp/dn2500'))
    ap.add_argument('--out-dir', default=None, help='logs (default: <work-dir>/run)')
    ap.add_argument('--ram', default='8M')
    ap.add_argument('--mem-limit', type=lambda s: int(s, 0), default=None, help='the PROM record\'s +4 (default: the RAM size)')
    ap.add_argument('--flags', type=lambda s: int(s, 0), default=0x0008)
    ap.add_argument('--frames', type=int, default=3600, help='frames to run after entering COLD')
    ap.add_argument('--prom-frames', type=int, default=120000, help='frames the PROM may take to reach its prompt '
                    '(its disk self-test, with a disk, takes far longer than the default)')
    ap.add_argument('--port', type=int, default=4321)
    ap.add_argument('--stuck-frames', type=int, default=300)
    ap.add_argument('--extra-stop', action='append', default=[])
    ap.add_argument('--extra-progress', action='append', default=[])
    ap.add_argument('--bp', action='append', default=[], help='raw MAME bpset arguments')
    ap.add_argument('--wp', action='append', default=[], help='raw MAME wpset arguments; the addresses are physical (the 68030\'s MMU is in the CPU, so the space watched is untranslated), e.g. '
                    "'0x4012002,2,w,1,{logerror \"WP pc=%%X data=%%X\\n\",pc,wpdata;go}'")
    ap.add_argument('--boot-dev', default='', help='8 hex bytes for the PROM record\'s boot device (+0x18), which the '
                    'PROM\'s BOOT path would fill; e.g. 1300005344202000 names win0 (a DCTE\'s reserved_1c, io/dctes.pas)')
    ap.add_argument('--hard', default=None, help='a SCSI disk image for scsi:0 (.hd raw or .chd)')
    ap.add_argument('--calendar', default='1991-06-01 12:00:00', help='the date written into the calendar at entry')
    ap.add_argument('--clean-volume', action='store_true', help='clear the --hard image\'s salvage flag and set its '
                    'last valid time from --calendar (a raw image of 1024-byte blocks, the LV label at block 1)')
    ap.add_argument('--trace-after', type=int, default=-1, help='trace the CPU to <out>/trace.txt from this many frames after entry')
    ap.add_argument('--trace-frames', type=int, default=2)
    ap.add_argument('--prom-wp', action='append', default=[], help='raw wpset arguments set at the first frame, '
                    'for the PROM\'s own tests (physical addresses: the PROM runs with the MMU off)')
    ap.add_argument('--prom-boot', action='store_true', help='let the PROM boot the --hard disk itself: answer `y\' '
                    'to its boot question and load nothing (--frames then counts from power-on)')
    ap.add_argument('--normal-mode', action='store_true', help='the mode switch at normal instead of service (with '
                    '--prom-boot, the harness types BOOT at the PROM\'s prompt)')
    ap.add_argument('--monitor', default='none', choices=['none', '1280x1024', '1024x800'],
                    help='the monitor the configuration reports (none: the PROM uses the serial line)')
    ap.add_argument('--key', action='append', default=[], metavar='FRAME:TEXT',
                    help='type TEXT on the keyboard FRAME frames after power-on (backslash escapes decoded, '
                    'e.g. 70000:boot\\r); repeat it')
    ap.add_argument('--type', action='append', default=[], metavar='TEXT',
                    help='type TEXT on the keyboard once the machine has waited for input for 60 frames (the '
                    'display console; backslash escapes decoded, e.g. y\\r); repeat it for each prompt in turn')
    ap.add_argument('--expect', dest='script', action='append', type=lambda t: ('expect', t), default=[],
                    help='(serial console) wait for TEXT, then go on with the next --send/--sleep; the steps run '
                    'in order and replace the canned answers (backslash escapes decoded)')
    ap.add_argument('--send', dest='script', action='append', type=lambda t: ('send', t),
                    help='(serial console) send TEXT')
    ap.add_argument('--sleep', dest='script', action='append', type=lambda t: ('sleep', t),
                    help='(serial console) wait SECONDS of real time (emulation runs at least as fast)')
    ap.add_argument('--finish-on', default=None, help='end the run once the serial console has shown TEXT')
    ap.add_argument('--console', default='serial', choices=['serial', 'keyboard'],
                    help='serial: the harness sends CRs on SIO1, which the PROM takes as its console; keyboard: it '
                    'sends nothing, so a Return typed with --key picks the keyboard and display')
    ap.add_argument('--screen', action='store_true', help='at the end, write the frame buffer to <out>/screen.png')
    ap.add_argument('--dump-pcbs', action='store_true', help='at the end, log each process\'s PCB and saved '
                    'frame chain (PCBS from the symbols)')
    args = ap.parse_args()

    out_dir = os.path.abspath(args.out_dir or os.path.join(args.work_dir, 'run'))
    os.makedirs(out_dir, exist_ok=True)
    syms = read_syms(args)
    syms_path = os.path.join(out_dir, 'syms.txt')
    with open(syms_path, 'w') as f:
        for n, a in sorted(syms.items(), key=lambda x: x[1]):
            f.write('%08x T %s\n' % (a, n))

    def addrs(names):
        return ','.join(str(syms[n] if n in syms else int(n, 16)) for n in names
                        if n in syms or n.lower().startswith('0x'))

    cal = datetime.datetime.strptime(args.calendar, '%Y-%m-%d %H:%M:%S')
    if args.clean_volume:
        # the system clock's high word counts 2^16 * 4 us from 1980
        secs = (cal - datetime.datetime(1980, 1, 1)).total_seconds() - 12 * 3600
        last_valid = int(secs * 250000) >> 16
        with open(args.hard, 'r+b') as hd:
            hd.seek(1024 + 0xCE)
            hd.write(b'\x00\x00')
            hd.seek(1024 + 0xE6)
            hd.write(last_valid.to_bytes(4, 'big'))
        print('label of %s: salvage flag cleared, last valid time 0x%08X' % (args.hard, last_valid))

    ram_bytes = int(args.ram[:-1]) << (20 if args.ram.endswith('M') else 10)
    lua = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mame_boot_dn2500.lua')
    env = dict(os.environ, DYLD_FRAMEWORK_PATH='/Library/Frameworks', SDL_VIDEODRIVER='dummy',
               DN_IMAGE=os.path.abspath(args.image), DN_SYMS=syms_path,
               DN_STOPS=addrs(STOP_SYMBOLS + args.extra_stop),
               DN_PROGRESS=addrs(PROGRESS_SYMBOLS + args.extra_progress),
               DN_FLAGS=str(args.flags), DN_FRAMES=str(args.frames), DN_PROM_FRAMES=str(args.prom_frames), DN_PROM_BOOT='1' if args.prom_boot else '', DN_NORMAL_MODE='1' if args.normal_mode else '',
               DN_TYPE='|'.join(t.encode().decode('unicode_escape') for t in args.type),
               DN_KEYS='|'.join(k.encode().decode('unicode_escape') for k in args.key),
               DN_MONITOR=args.monitor, DN_FB_DUMP=os.path.join(out_dir, 'screen.pbm') if args.screen else '',
               DN_RECORD=str(PROM_RECORD),
               DN_MEM_LIMIT=str(args.mem_limit if args.mem_limit is not None else ram_bytes),
               DN_STUCK_FRAMES=str(args.stuck_frames), DN_BOOT_DEV=args.boot_dev,
               DN_CALENDAR='%d,%d,%d,%d,%d,%d,%d' % (cal.year % 100, cal.month, cal.day,
                                                     cal.isoweekday() % 7 + 1, cal.hour, cal.minute, cal.second),
               DN_RAW_BPS='|'.join(args.bp), DN_RAW_WPS='|'.join(args.wp), DN_PROM_WPS='|'.join(args.prom_wp),
               DN_TRACE_AFTER=str(args.trace_after), DN_TRACE_FRAMES=str(args.trace_frames),
               DN_PCBS=str(syms['PCBS']) if args.dump_pcbs and 'PCBS' in syms else '',
               DN_OUT=out_dir)
    # A fresh calendar RAM each run: the PROM keeps state there across
    # boots (a run after another reaches `>' without the self-test
    # question).
    nvram_dir = os.path.join(out_dir, 'nvram')
    shutil.rmtree(nvram_dir, ignore_errors=True)
    # and fresh settings: MAME keeps the configuration switches in cfg
    cfg_dir = os.path.join(out_dir, 'cfg')
    shutil.rmtree(cfg_dir, ignore_errors=True)
    # the switches the PROM reads at reset (the mode and the monitor), set
    # before MAME starts: a script runs after the first reset
    os.makedirs(cfg_dir)
    monitor = {'none': 0x30, '1280x1024': 0x10, '1024x800': 0x00}[args.monitor]
    with open(os.path.join(cfg_dir, 'dn2500.cfg'), 'w') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<mameconfig version="10">\n'
                '    <system name="dn2500">\n        <input>\n'
                '            <port tag=":CONFIG" type="CONFIG" mask="1" defvalue="1" value="%d" />\n'
                '            <port tag=":CONFIG" type="CONFIG" mask="48" defvalue="16" value="%d" />\n'
                '        </input>\n    </system>\n</mameconfig>\n'
                % (0 if args.normal_mode else 1, monitor))
    cmd = [args.mame_bin, 'dn2500', '-ram', args.ram.lower(), '-rompath', os.path.abspath(args.rompath),
           '-cfg_directory', cfg_dir,
           '-nvram_directory', nvram_dir,
           '-rs232a', 'null_modem', '-bitb', 'socket.127.0.0.1:%d' % args.port,
           '-video', 'none', '-sound', 'none', '-log', '-skip_gameinfo', '-nothrottle',
           '-debug', '-debugger', 'none', '-autoboot_script', lua]
    if args.hard:
        cmd += ['-hard', os.path.abspath(args.hard)]

    done, log = threading.Event(), []
    console = os.path.join(out_dir, 'console.txt')
    t = threading.Thread(target=console_server, args=(args.port, console,
                         [('(y,n)?', 'y' if args.prom_boot else 'n')]
                         + ([('\n>', 'BOOT\r')] if args.prom_boot and args.normal_mode else [])
                         + ([('\n)', 'go\r')] if args.prom_boot else []), done, log, os.path.join(out_dir, 'prompt'), args.console == 'serial',
                         [(k, v.encode().decode('unicode_escape') if k != 'sleep' else v) for k, v in args.script],
                         (args.finish_on, os.path.join(out_dir, 'finish')) if args.finish_on else None), daemon=True)
    t.start()
    time.sleep(0.5)
    elog = os.path.join(args.work_dir, 'error.log')
    if os.path.exists(elog):
        os.remove(elog)
    res = subprocess.run(cmd, cwd=args.work_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    done.set()
    t.join(2)
    text = res.stdout.decode(errors='replace')
    open(os.path.join(out_dir, 'mame.out'), 'w').write(text)
    pbm = os.path.join(out_dir, 'screen.pbm')
    if args.screen and os.path.exists(pbm):
        try:
            from PIL import Image, ImageOps
            w, h = (1024, 800) if args.monitor == '1024x800' else (1280, 1024)
            # a set bit is a lit pixel on the screen; PBM's 1 is black
            img = ImageOps.invert(Image.open(pbm).convert('L')).crop((0, 0, w, h))
            img.save(os.path.join(out_dir, 'screen.png'))
        except ImportError:
            pass
    for line in text.splitlines():
        if line.startswith('BOOT ') or line.startswith('D0=') or line.startswith('A0=') or 'rror' in line:
            print(line)
    for l in log:
        print(l)
    print('mame exit code', res.returncode)
    if os.path.exists(elog):
        os.replace(elog, os.path.join(out_dir, 'error.log'))
        lines = open(os.path.join(out_dir, 'error.log'), errors='replace').read().splitlines()
        keep = [l for l in lines if 'PROGRESS' in l or 'STOP' in l or 'EXC' in l or 'unmapped' in l]
        print('error.log: %d lines, %d of interest; first 60:' % (len(lines), len(keep)))
        for l in keep[:60]:
            print('  ' + l)
    if os.path.exists(console):
        c = open(console, 'rb').read().decode('latin-1')
        tail = c[c.rfind('continue with the system BOOT'):] if 'continue with the system BOOT' in c else c
        print('console after the PROM prompt (%d bytes in all):' % len(c))
        print(tail[-3000:])


if __name__ == '__main__':
    main()
