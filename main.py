#!/usr/bin/env python3

import os
import sys

from terminal import Terminal


def main():
    with Terminal() as tty:
        print('-> TTY name: `{}`'.format(tty.tty_name))
        tty.spawn(['/usr/bin/tty']).wait()
        tty_output = tty.read(100)
        print('-> Output of `tty` command: {}'.format(repr(tty_output.decode())))

if __name__ == '__main__':
    main()
