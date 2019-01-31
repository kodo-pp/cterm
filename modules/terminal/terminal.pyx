# distutils: language = c++
# cython: language_level = 3

cimport libc.stdlib as stdlib
cimport libc.errno  as errno
cimport libc.string as string
cimport posix.fcntl as fcntl
cimport posix.stdlib as posix_stdlib
cimport posix.unistd as unistd
cimport posix.ioctl as ioctl
cimport libcpp.string as cxx_string

import os
import sys
import subprocess as sp


cdef extern from '<stdlib.h>' nogil:
    int grantpt(int)
    int ptsname_r(int, char*, size_t)
    int close(int)


cdef extern from '<termios.h>' nogil:
    enum: TIOCSCTTY
    enum: TIOCNOTTY


def read_fd(fd: int, length: int) -> bytes:
    return os.read(fd, length)


def write_fd(fd: int, data: bytes):
    length = len(data)
    n = 0
    cdef cxx_string.string buf = data
    while n < length:
        written_now = unistd.write(fd, buf.c_str() + <size_t>n, length - n)
        if written_now <= 0:
            # I really don't understand wtf is happening when write(2) returns 0, so I'll consider it an error
            raise OSError(errno.errno, os.strerror(errno.errno))
        n += written_now


class Terminal:
    def __init__(self):
        cdef int tty_fd = fcntl.open('/dev/ptmx', fcntl.O_RDWR | os.O_CLOEXEC)
        if tty_fd < 0:
            raise OSError(errno.errno, os.strerror(errno.errno), '/dev/ptmx')
        if posix_stdlib.unlockpt(tty_fd) < 0:
            raise OSError(errno.errno, os.strerror(errno.errno))
        if grantpt(tty_fd) < 0:
            raise OSError(errno.errno, os.strerror(errno.errno))

        cdef char tty_name_c[4096]
        string.memset(tty_name_c, 0, sizeof(tty_name_c))
        if ptsname_r(tty_fd, tty_name_c, 4096) != 0:
            raise OSError(errno.errno, os.strerror(errno.errno))
        
        self.tty_fd = int(tty_fd)
        self.tty_name = bytes(tty_name_c).decode()


    def write(self, data):
        if type(data) is str:
            data = data.encode('utf-8')
        if type(data) is not bytes:
            raise TypeError('data must be str or bytes')
        return write_fd(self.tty_fd, data)


    def read(self, length):
        return read_fd(self.tty_fd, length)


    def __enter__(self, *a):
        return self

    
    def __exit__(self, *a):
        self.close()


    def close(self):
        if close(self.tty_fd) < 0:
            raise OSError(errno.errno, os.strerror(errno.errno))


    def spawn(self, args):
        pid = os.fork()
        if pid == 0:
            # Child process
            pts_fd = os.open(self.tty_name, os.O_RDWR)
            with os.fdopen(pts_fd, 'r+b', buffering=0) as pts:
                #if ioctl.ioctl(pts_fd, TIOCNOTTY) < 0:
                #    raise OSError(errno.errno, os.strerror(errno.errno))
                os.setsid()
                if ioctl.ioctl(pts_fd, TIOCSCTTY, 0) < 0:
                    raise OSError(errno.errno, os.strerror(errno.errno))
                os.dup2(pts_fd, 0)
                os.dup2(pts_fd, 1)
                os.dup2(pts_fd, 2)
                os.execv(args[0], args)
        else:
            # Parent process
            return pid
