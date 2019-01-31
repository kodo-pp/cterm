#!/usr/bin/env python3

import os
import sys
import select
import termios
import copy
from threading import Lock, Thread

from terminal import Terminal


def io_func(tty):
    while True:
        rlist, wlist, xlist = select.select([sys.stdin, tty.tty_fd], [], [])
        if tty.tty_fd in rlist:
            out = tty.read(1000)
            sys.stdout.buffer.write(out)
            sys.stdout.flush()

        if sys.stdin in rlist:
            # XXX: ***SLIGHTLY*** inefficient
            c = sys.stdin.buffer.read(1)
            tty.write(c)

def main():
    orig_tcattr = termios.tcgetattr(sys.stdin)
    new_tcattr = copy.deepcopy(orig_tcattr)
    with Terminal() as tty:        
        print('-> TTY name: `{}`'.format(tty.tty_name))
        print('-> Spawning a shell')
        pid = tty.spawn(['/usr/bin/env', '--unset=PS1', '/usr/bin/bash', '--norc', '--noprofile'])
        print('-> Starting io thread')
        io_thread = Thread(target=io_func, args=[tty], daemon=True)
        io_thread.start()
        os.waitpid(pid, 0)

if __name__ == '__main__':
    main()
