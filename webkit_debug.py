#!/usr/bin/env python
import gdb
import os

def wpet_get(option):
    return os.environ.get('WPET_' + option, None)

have_wpet_config = bool(wpet_get('CONFIG_PARSED'))
if not have_wpet_config:
    raise RuntimeError("config.sh not sourced")


BUILDROOT_OUTPUT = wpet_get('OUTPUT')
WPE_BUILD = wpet_get('WPE_BUILD')

REMOTE = wpet_get('REMOTE_HOST') + ':' + wpet_get('REMOTE_GDB_PORT')

settings = {
    'sysroot': os.path.join(BUILDROOT_OUTPUT, 'staging'),
    'pagination': 'off',
    'print pretty': 'on',
    'print object': 'on'
}

directory = [ os.path.join(WPE_BUILD, 'Source', val)
            for val in ['JavaScriptCore', 'WTF', 'WebCore', 'WPE', 'WebKit2'] ]


other_init_commands = [
    "directory %s" % ":".join(directory),
    #"handle SIGILL nostop",
    "file %s" % os.path.join(BUILDROOT_OUTPUT, 'staging/usr/bin/WPELauncher'),
    "target remote %s" % REMOTE
]

def setup():
    for key,val in settings.iteritems():
        gdb.execute("set %s %s" % (key, val))

    for command in other_init_commands:
        gdb.execute(command)

setup()


# FIXME: split webkit helper stuff in separate file

class JSBTCommand(gdb.Command):
    def __init__(self, **kwargs):
        gdb.Command.__init__(self, "jsbt", gdb.COMMAND_STACK, gdb.COMPLETE_EXPRESSION)

    def invoke(self, arguments, from_tty):
        argv = gdb.string_to_argv(arguments)
        argc = len(argv)
        context=None
        maxStackSize=50
        if not argc in (1, 2):
            print "syntax: jsbt <context> [max stack size]"
            return
        if argc >= 1:
            context = argv[0]
        if argc >= 2:
            maxStackSize = argv[1]
        call = "JSContextCreateBacktrace((JSContextRef)%s, %d)->m_string.m_impl.m_ptr->m_data8" % (context, maxStackSize)
        print "Trying to call", call
        print gdb.parse_and_eval(call).string()

JSBTCommand()


# FIXME: split generic gdb helper stuff in separate file

def get_ptr_val(ptr):
    try:
        #return int(str(ptr.cast(VOIDP)), 16)
        return int(ptr.cast(INT))
    except Exception, e:
        import pdb; pdb.set_trace()
    #return int(str(ptr.dereference().address), 16)

class MemoryAddress():
    def __init__(self, addr):
        if isinstance(addr, int):
            self._val = addr
        elif isinstance(addr, gdb.Value):
            self._val = get_ptr_val(addr)
        else:
            raise TypeError("Unhandled format %s for %s" % (type(addr), addr))

    def loc(self):
        return "* 0x%x" % self._val

    def val(self):
        return self._val

    def __cmp__(self, other):
        return cmp(self.val(), other.val())

    def __str__(self):
        return "0x%x" % self._val

    def __repr__(self):
        return "MemoryAddress(0x%x)" % self._val

class EasyBreakpoint(gdb.Breakpoint):
    def __init__(self, loc, stop_cb=None, **kargs):
        if isinstance(loc, MemoryAddress):
            loc_ = loc.loc()
        else:
            loc_ = loc

        gdb.Breakpoint.__init__(self, loc_, **kargs)

        self._stop_cb = stop_cb

    def stop(self):
        if self._stop_cb:
            return self._stop_cb(self)
        return True

def gdb_break(*args, **kargs):
    return EasyBreakpoint(*args, **kargs)

class EasyFinishBreakpoint(gdb.FinishBreakpoint):
    def __init__(self, frame, stop_cb=None, **kargs):
        gdb.FinishBreakpoint.__init__(self, frame, **kargs)
        self._stop_cb = stop_cb

    def stop(self):
        if self._stop_cb:
            return self._stop_cb(self)
        return True

def gdb_fin(*args, **kargs):
    return EasyFinishBreakpoint(*args, **kargs)

