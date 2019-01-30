# distutils: language = c++
# cython: language_level = 3

cimport libc.stdlib as stdlib
cimport libc.errno  as errno
cimport libc.string as string
cimport posix.fcntl as fcntl
cimport posix.stdlib as posix_stdlib
cimport posix.unistd as unistd
cimport libcpp.string as cxx_string

import os
import subprocess as sp


cdef extern from '<stdlib.h>' nogil:
    int grantpt(int)
    int ptsname_r(int, char*, size_t)
    int close(int)


def read_fd(fd: int, length: int, complete: bool) -> bytes:
    n = 0
    cdef cxx_string.string buf
    buf.resize(length)
    while n < length:
        read_now = unistd.read(fd, <char*>buf.c_str() + <size_t>n, length - n)
        if read_now <= 0:
            # I really don't understand wtf is happening when read(2) returns 0, so I'll consider it an error
            raise OSError(errno.errno, os.strerror(errno.errno))
        if not complete:
            buf.resize(read_now)
            return bytes(buf)
        n += read_now
    return bytes(buf)


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
        cdef int tty_fd = fcntl.open('/dev/ptmx', fcntl.O_RDWR)
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


    def read(self, length, complete=False):
        return read_fd(self.tty_fd, length, complete)


    def __enter__(self, *a):
        return self

    
    def __exit__(self, *a):
        self.close()


    def close(self):
        if close(self.tty_fd) < 0:
            raise OSError(errno.errno, os.strerror(errno.errno))


    def spawn(self, *args, **kwargs):
        with open(self.tty_name, 'r+b', buffering=0) as pts:
            return sp.Popen(*args, **kwargs, stdin=pts, stdout=pts, stderr=pts)
