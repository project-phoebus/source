#!/usr/bin/env python3
"""mame_boot_dn3500.py - boot an SR10.2 volume on MAME's DN3500 (SAU7) from power-on.

The DN3500's boot PROM (MD7C rev 8.00) boots the disk itself: the harness
only sets the calendar (binary, at frame 1), types on the keyboard, and
watches.  The disk is the OMTI 8621's .awd (1056-byte blocks: a 32-byte
header and 1024 data bytes).  The console text is the PROM's character
output routine (PROM entry 0x108 -> 0x2142, the character in D1), which
the PROM, sysboot, Phase II and the kernel's console all use; a breakpoint
there collects it into <out>/console.txt, for --expect.

Stages, in order: [--wait FRAMES] [--expect TEXT] --type TEXT.  A stage is
typed once the console has shown TEXT since the previous stage, at least
FRAMES frames after it, and once the CPU idles (NULL_LOOP, or the PC stays
put 30 frames; or 300 frames after the rest held).

    mame_boot_dn3500.py --hard <copy.awd> --elf build/sau7/domain_os.elf \\
        --out-dir <dir> --service --clean-volume --calendar '1991-06-02 12:00:00' \\
        --frames 60000 --wait '1200!' --type '\\r' --expect '>' \\
        --type 'ex domain_os\\r' --type 'go\\r'

The PROM runs in Service mode (--service): in Normal mode its power-up
serial loopback test waits for ever under MAME.  It has no BOOT command;
`ex domain_os' at its `>' prompt loads /sau7/domain_os.  The disk is a
copy; never pass the original volume.

Everything MAME writes (cfg, nvram, error.log, snapshots) is under --out-dir.
"""
import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys

STOP_SYMBOLS = ['CRASH_SYSTEM', 'FIM_$CRASH', 'FIM_$UII', 'FIM_$PRIV_VIOL',
                'FIM_$FLINE', 'FIM_$SPURIOUS_INT', 'FIM_$PARITY_TRAP', 'FIM_$NMI']
PROGRESS_SYMBOLS = ['OS_$COLD_START', 'OS_$INIT', 'MMU_$INIT', 'MMAP_$INIT', 'TIME_$INIT',
                    'PROC1_$INIT', 'PEB_$INIT', 'IO_$INIT', 'TIMER_$INIT', 'ATBUS_$INIT',
                    'WIN8_$DINIT', 'WIN7_$DINIT', 'FIM_$INIT', 'AST_$INIT', 'AREA_$INIT', 'MST_$INIT',
                    'DISK_$INIT', 'NETWORK_$INIT', 'FILE_$INIT', 'VTOC_$INIT', 'OS_$START_PROC2', 'CAL_$INIT']
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, '..', '..'))
ARCH = os.path.dirname(SRC)


def read_syms(args):
    syms = {}
    if args.map:
        for line in open(args.map, errors='replace'):
            m = re.match(r'^\s*(?:[A-Z]\d*\s+)?([0-9A-F]{6,8})\s+([A-Z_$][\w$]*)', line)
            if m and m.group(2) not in ('size', 'loaded'):
                syms.setdefault(m.group(2), int(m.group(1), 16))
    elif args.elf:
        nm = subprocess.check_output(['m68k-elf-nm', args.elf]).decode()
        for line in nm.splitlines():
            p = line.split()
            if len(p) == 3 and p[1] in 'TtDdBb':
                syms.setdefault(p[2], int(p[0], 16))
    return syms


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--machine', default='dn3500', help='dn3500 (15", the graphics option from --graphics) or dn3500_19i')
    ap.add_argument('--graphics', default='mono15', choices=['8plane', '4plane', 'mono15'],
                    help='dn3500\'s "Graphics Controller" configuration')
    ap.add_argument('--service', action='store_true', help='the Normal/Service switch at Service (default Normal)')
    ap.add_argument('--elf', default=None, help='symbols from this ELF (our kernel)')
    ap.add_argument('--map', default=None, help='symbols from this SAU7 link map (the original kernel)')
    ap.add_argument('--mame-bin', default=os.path.join(ARCH, 'mame/phoebus'))
    ap.add_argument('--rompath', default=os.path.join(ARCH, 'roms'))
    ap.add_argument('--out-dir', required=True)
    ap.add_argument('--hard', required=True, help='the OMTI disk image (.awd); modified by the run')
    ap.add_argument('--ram', default='16M')
    ap.add_argument('--frames', type=int, default=36000)
    ap.add_argument('--calendar', default='1991-06-01 12:00:00')
    ap.add_argument('--clean-volume', action='store_true', help='clear the LV label\'s salvage flag and set its last '
                    'valid time 12 hours before --calendar (block 1, data bytes 0xCE and 0xE6)')
    ap.add_argument('--expect', dest='stages', action='append', type=lambda t: ('expect', t), default=[])
    ap.add_argument('--wait', dest='stages', action='append', type=lambda t: ('wait', t))
    ap.add_argument('--type', dest='stages', action='append', type=lambda t: ('type', t))
    ap.add_argument('--finish-on', default='')
    ap.add_argument('--finish-after', type=int, default=-1, help='end the run this many frames after the last stage')
    ap.add_argument('--snap-every', type=int, default=0)
    ap.add_argument('--bp', action='append', default=[])
    ap.add_argument('--extra-stop', action='append', default=[])
    ap.add_argument('--extra-progress', action='append', default=[])
    ap.add_argument('--dump-pcbs', action='store_true')
    ap.add_argument('--console-addr', default='0x216e')
    ap.add_argument('--window', action='store_true', help='a real window instead of -video none (no debugger)')
    args = ap.parse_args()

    out_dir = os.path.abspath(args.out_dir)
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
        secs = (cal - datetime.datetime(1980, 1, 1)).total_seconds() - 12 * 3600
        last_valid = int(secs * 250000) >> 16
        with open(args.hard, 'r+b') as hd:
            hd.seek(1056 + 32 + 0xCE)
            hd.write(b'\x00\x00')
            hd.seek(1056 + 32 + 0xE6)
            hd.write(last_valid.to_bytes(4, 'big'))
        print('label of %s: salvage flag cleared, last valid time 0x%08X' % (args.hard, last_valid))

    # stages: [wait] [expect] type
    stages, pend = [], {'wait': '', 'expect': ''}
    for kind, val in args.stages:
        val = val.encode().decode('unicode_escape') if kind != 'wait' else val
        if kind == 'type':
            stages.append('%s\x1e%s\x1e%s' % (pend['wait'], pend['expect'], val))
            pend = {'wait': '', 'expect': ''}
        else:
            pend[kind] = val

    for d in ('cfg', 'nvram', 'snap'):
        shutil.rmtree(os.path.join(out_dir, d), ignore_errors=True)
    os.makedirs(os.path.join(out_dir, 'cfg'))
    # apollo_config: Normal/Service 0x01 (1 = Normal), Graphics 0x06?  The
    # masks: see apollo.h APOLLO_CONF_*; written as a cfg MAME reads before reset
    gfx = {'8plane': None, '4plane': None, 'mono15': None}
    lua = os.path.join(HERE, 'mame_boot_dn3500.lua')
    env = dict(os.environ, DYLD_FRAMEWORK_PATH='/Library/Frameworks', SDL_VIDEODRIVER='dummy',
               DN_SYMS=syms_path, DN_OUT=out_dir,
               DN_STOPS=addrs(STOP_SYMBOLS + args.extra_stop),
               DN_PROGRESS=addrs(PROGRESS_SYMBOLS + args.extra_progress),
               DN_RAW_BPS='|'.join(args.bp), DN_CONSOLE=str(int(args.console_addr, 0)),
               DN_STAGES='\x1f'.join(stages), DN_FRAMES=str(args.frames),
               DN_FINISH_ON=args.finish_on.encode().decode('unicode_escape'),
               DN_FINISH_AFTER=str(args.finish_after), DN_SNAP_EVERY=str(args.snap_every),
               DN_PCBS=str(syms['PCBS']) if args.dump_pcbs and 'PCBS' in syms else '',
               DN_CALENDAR='%d,%d,%d,%d,%d,%d,%d' % (cal.year % 100, cal.month, cal.day,
                                                     cal.isoweekday() % 7 + 1, cal.hour, cal.minute, cal.second))
    conf = apollo_conf(args)
    with open(os.path.join(out_dir, 'cfg', args.machine + '.cfg'), 'w') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<mameconfig version="10">\n'
                '    <system name="%s">\n        <input>\n%s        </input>\n    </system>\n</mameconfig>\n'
                % (args.machine, ''.join('            <port tag=":apollo_config" type="CONFIG" mask="%d" '
                                         'defvalue="%d" value="%d" />\n' % c for c in conf)))
    cmd = [args.mame_bin, args.machine, '-ram', args.ram.lower(), '-rompath', args.rompath,
           '-cfg_directory', os.path.join(out_dir, 'cfg'), '-nvram_directory', os.path.join(out_dir, 'nvram'),
           '-snapshot_directory', os.path.join(out_dir, 'snap'),
           '-sound', 'none', '-skip_gameinfo', '-log', '-disk1', os.path.abspath(args.hard)]
    if args.window:
        cmd += ['-window', '-nomaximize', '-nofilter', '-nounevenstretch']
        env.pop('SDL_VIDEODRIVER')
    else:
        cmd += ['-video', 'none', '-nothrottle', '-debug', '-debugger', 'none', '-autoboot_script', lua]
    print(' '.join(cmd))
    elog = os.path.join(out_dir, 'error.log')
    if os.path.exists(elog):
        os.remove(elog)
    res = subprocess.run(cmd, cwd=out_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    text = res.stdout.decode(errors='replace')
    open(os.path.join(out_dir, 'mame.out'), 'w').write(text)
    for line in text.splitlines():
        if line.startswith('BOOT ') or line.startswith('D0=') or line.startswith('A0=') or 'rror' in line:
            print(line)
    print('mame exit code', res.returncode)
    if os.path.exists(elog):
        lines = open(elog, errors='replace').read().splitlines()
        keep = [l for l in lines if 'PROGRESS' in l or 'STOP' in l]
        print('error.log: %d lines, %d PROGRESS/STOP; first 60:' % (len(lines), len(keep)))
        for l in keep[:60]:
            print('  ' + l)
    con = os.path.join(out_dir, 'console.txt')
    if os.path.exists(con):
        c = open(con, 'rb').read().decode('latin-1')
        print('console (%d bytes), last 2500:' % len(c))
        print(c[-2500:])
    snaps = sorted(os.listdir(os.path.join(out_dir, 'snap', args.machine))) if os.path.isdir(
        os.path.join(out_dir, 'snap', args.machine)) else []
    print('snapshots:', ', '.join(os.path.join(out_dir, 'snap', args.machine, s) for s in snaps[-3:]))


def apollo_conf(args):
    """(mask, default, value) for the apollo_config port (apollo.h)"""
    hdr = open(os.path.join(ARCH, 'mame/src/mame/apollo/apollo.h')).read()
    def c(name):
        m = re.search(r'#define\s+APOLLO_CONF_%s\s+(0x[0-9a-fA-F]+|\d+)' % name, hdr)
        return int(m.group(1), 0)
    svc = c('SERVICE_MODE')
    disp = c('DISPLAY')
    gval = {'8plane': c('8_PLANES'), '4plane': c('4_PLANES'), 'mono15': c('MONO_15I')}[args.graphics]
    return [(svc, 0, 0 if args.service else svc), (disp, c('8_PLANES'), gval)]


if __name__ == '__main__':
    main()
