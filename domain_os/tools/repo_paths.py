#!/usr/bin/env python3
"""Where the tools look for what lives outside this repository (the SR10.2
install tree, the link maps, MAME, the Pascal compiler): by default in
directories beside the repository's checkout, REPO_PARENT, as the Makefile
does.  From a git worktree that is the main checkout's parent."""

import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))       # domain_os/tools


def _repo_parent():
    try:
        d = subprocess.run(['git', '-C', HERE, 'rev-parse', '--path-format=absolute',
                            '--git-common-dir'], capture_output=True, text=True,
                           check=True).stdout.strip()
        if d:
            return os.path.dirname(os.path.dirname(d))  # <parent>/<repo>/.git
    except (OSError, subprocess.CalledProcessError):
        pass
    return os.path.abspath(os.path.join(HERE, '..', '..', '..'))


REPO_PARENT = _repo_parent()


def beside(*parts):
    """A path under REPO_PARENT."""
    return os.path.join(REPO_PARENT, *parts)
