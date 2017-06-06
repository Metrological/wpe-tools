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

DEBUG_PROGRAM = wpet_get('DEBUG_ATTACH')
if DEBUG_PROGRAM is None:
    DEBUG_PROGRAM = wpet_get('DEBUG_PROGRAM')

TARGET_PLATFORM = wpet_get('PLATFORM')


def get_fp(platform):
    fps = { 'mipsel-linux': '$s8',
            'arm-linux': '$r7' # ARM "traditional" would use $r11
            }
    return fps.get(platform, None)

frame_pointer = get_fp(TARGET_PLATFORM)


settings = {
    'sysroot': os.path.join(BUILDROOT_OUTPUT, 'staging'),
    'pagination': 'off',
    'print pretty': 'on',
    'print object': 'on'
}

directory = [ os.path.join(WPE_BUILD, 'Source', val)
            for val in ['JavaScriptCore', 'WTF', 'WebCore',  'WebKit2'] ]


other_init_commands = [
    "directory %s" % ":".join(directory),
    "handle SIGILL nostop",
    "handle SIGUSR1 nostop noprint",
    "handle SIGUSR2 nostop noprint",
    "file %s" % os.path.join(BUILDROOT_OUTPUT, 'staging/usr/bin/%s' % DEBUG_PROGRAM),
    "target remote %s" % REMOTE
]

if wpet_get('DEBUG_CONTINUE_ON_ATTACH') is not None:
    settings['interactive-mode'] = 'off'
    other_init_commands.append("continue")
    other_init_commands.append("bt")
    other_init_commands.append("kill")
    other_init_commands.append("quit")


def setup():
    for key,val in settings.iteritems():
        gdb.execute("set %s %s" % (key, val))

    for command in other_init_commands:
        gdb.execute(command)

setup()




# FIXME: split generic gdb helper stuff in separate file

class EasyCommand(gdb.Command):
    def __init__(self, name, invokecb):
        self._invokecb = invokecb
        gdb.Command.__init__(self, name, gdb.COMMAND_NONE, gdb.COMPLETE_EXPRESSION)

    def invoke(self, arguments, from_tty):
        return self._invokecb(gdb.string_to_argv(arguments), from_tty)

def gdb_command(name, invokecb):
    return EasyCommand(name, invokecb)


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

def read_word(inferior, address):
    buf = inferior.read_memory(address, 4)
    result = 0
    for i,c in enumerate(buf):
        result += ord(c) << 8 * i
    return result

# FIXME: split webkit helper stuff in separate file

VOIDP = gdb.lookup_type("void").pointer()
FUNCTIONCODEBLOCKP = VOIDP # gdb.lookup_type("JSC::FunctionCodeBlock").pointer()
INT = gdb.lookup_type("int")

def wtf_string_to_utf8(val, inferior=None):
    if inferior is None:
        inferior = gdb.selected_inferior()
    length = int(val["m_impl"]["m_ptr"]["m_length"])
    if length == 0:
        return ""
    data_addr = get_ptr_val(val["m_impl"]["m_ptr"]["m_data8"])
    try:
        return "0x%x, %d: %s" % (data_addr, length, str(inferior.read_memory(data_addr, length)))
    except gdb.MemoryError, e:
        return "memory error 0x%x, %d" % (data_addr, length)



class CodeBlock:
    def __init__(self, gdb_val):
        self.val = gdb_val
        try:
            jitcode = gdb_val["m_jitCode"]["m_ptr"]
            self._jitcode = jitcode.cast(jitcode.dynamic_type)
            self._start = self._jitcode["m_ref"]["m_codePtr"]["m_value"]
            size = self._jitcode["m_ref"]["m_executableMemory"]["m_ptr"]["m_sizeInBytes"]
            self._end = self._start + size
        except Exception, e:
            print "Corrupted CodeBlock at", gdb_val, ":", e
            self._start = 0
            self._end = 0


    def start(self):
        return self._start

    def end(self):
        return self._end

    def _applyNoArgMethod(self, method):
        gdb.parse_and_eval("((CodeBlock *)0x%x)->%s()" % \
                (get_ptr_val(self.val), method))

    def dumpByteCode(self):
        self._applyNoArgMethod("dumpByteCode")

    def dumpSource(self):
        self._applyNoArgMethod("dumpSource")

    def vm(self):
        return self.val['m_vm']

    def __repr__(self):
        return "<CodeBlock 0x%x start:0x%x end:0x%x>" % (self.val,
                self._start, self._end)

    def __str__(self):
        return self.__repr__()


class FrameItem:
    def __init__(self, id_number, description, offset, gdb_type):
        self.id_number = id_number
        self.description = description
        self.offset = offset
        self.gdb_type = gdb_type

    def __repr__(self):
        return "FrameItem(%d, %s, %d, %s)" % (self.id_number,
                self.description, self.offset, self.gdb_type)

class Frame:
    RET_OFFSET = 4
    CALLEE_OFFSET = 16
    # frame info
    PARENT = 0
    RET = 1
    CODEBLOCK = 2
    CALLEE = 3
    ARG_COUNT = 4
    VPC = 5
    THIS = 6
    LAST = THIS
    ITEMS_SIZE = LAST + 1

    # These offsets are valid for MIPS32
    items_info = [
            FrameItem(PARENT, "parent frame", 0, VOIDP),
            FrameItem(RET, "return addr", 4, VOIDP),
            FrameItem(CODEBLOCK, "CodeBlock", 8, FUNCTIONCODEBLOCKP),
            FrameItem(CALLEE, "callee", 16, VOIDP), # FIXME
            FrameItem(ARG_COUNT, "arg count", 24, INT),
            FrameItem(VPC, "vPC", 28, VOIDP), # FIXME
            FrameItem(THIS, "this", 32, VOIDP) # FIXME
            ]

    FIRST_ARG_OFFSET = items_info[LAST].offset + 8

    #get_name_str = "((JSC::JSFunction *)0x%x)->name((JSC::ExecState*)0x%x).m_impl.m_ptr->m_data8"
    get_name_str = "JSC::getCalculatedDisplayName(*((JSC::VM*)0x%x), (JSC::JSObject*)0x%x)"

    def __init__(self, addr, pc=None, inferior=None):
        self.addr = addr
        self.pc = pc
        self.inferior = inferior
        if inferior is None:
            self.inferior = gdb.selected_inferior()

        items = [None] * self.ITEMS_SIZE
        for frame_item in self.items_info:
            items[frame_item.id_number] = self.read_item(frame_item)
        self.items = items

        self.is_valid_frame = self.validate()
        self.is_valid_js_frame = self.is_valid_frame and self.js_validate()

        if self.is_valid_js_frame:
            self.codeBlock = CodeBlock(self.items[self.CODEBLOCK])

    def topy(self, item_id):
        item_val = self.items[item_id]
        return int(item_val.cast(INT))

    def validate(self):
        """Check whether the basic info in this frame makes sense"""
        parent_frame_addr = self.topy(self.PARENT)
        size = parent_frame_addr - self.addr
        return size > 4 and size < 1000

    def js_validate(self):
        """Check whether this is a proper js frame"""
        expected_frame_size = self.items_info[self.LAST].offset + 8 \
                + 8 * self.items[self.ARG_COUNT]
        parent_frame_addr = self.topy(self.PARENT)
        return (parent_frame_addr - self.addr) >= expected_frame_size

    def read_item(self, frame_item):
        try:
            val = read_word(self.inferior, self.addr + frame_item.offset)
        except Exception, e:
            print "Could not read item %s at 0x%x: %s" % (frame_item,
                                                self.addr+frame_item.offset,
                                                e)
            import pdb; pdb.set_trace()
        return gdb.Value(val).cast(frame_item.gdb_type)

    def get_arg(self, arg_id):
        val = read_word(self.inferior,
                self.addr + self.FIRST_ARG_OFFSET + 8 * arg_id)
        return gdb.Value(val).cast(VOIDP)

    def __repr__(self):
        val ="<Frame 0x%x" % self.addr 
        if self.pc is not None:
            val +=" Ret PC: " + str(gdb.Value(self.pc).cast(VOIDP))
        else:
            val += " Ret PC: ?"


        val += " Func: " + self.get_func_name()

        if self.is_valid_js_frame:
            val += "(%s -> %s)" % (self.codeBlock.start(),
                    self.codeBlock.end())

        val += ">"

        return val

    def __str__(self):
        return self.__repr__()

    def long_str(self):
        ret = ""
        if self.is_valid_js_frame:
            n = self.LAST+1
        else:
            n = self.RET + 1
        for item_info in self.items_info[:n]:
            if item_info.id_number == self.CODEBLOCK and self.is_valid_js_frame:
                ret += "CodeBlock:\t%s\n" % self.codeBlock
            else:
                ret += "%s:\t%s\n" % (item_info.description,
                        self.items[item_info.id_number])

        if self.is_valid_js_frame:
            for i in xrange(self.topy(self.ARG_COUNT)):
                ret += "Arg %d:\t%s\n" % (i, self.get_arg(i))

        return ret

    def is_js_frame(self):
        return self.is_valid_js_frame

    def get_func_name(self):
        if self.pc is not None:
            try:
                block = gdb.block_for_pc(self.pc)
                if block is not None:
                    if block.function is not None:
                        return block.function.name
                    if block.superblock is not None and block.superblock.function is not None:
                        return block.superblock.function.name
            except RuntimeError:
                pass

        if self.is_js_frame():
            js_function_addr = self.topy(self.CALLEE)
            vm = self.codeBlock.vm()
            to_call = self.get_name_str % (vm, js_function_addr)
            #print "about to call " + to_call
            val = gdb.parse_and_eval(to_call)
            return "js: "+wtf_string_to_utf8(val)

        return "<unknown native func>"

    def parent_frame(self):
        if not self.is_valid_frame:
            return None
        addr = self.topy(self.PARENT)
        pc = self.topy(self.RET)
        return Frame(addr, pc, self.inferior)

def read_frames(frames_so_far):
    last_frame = frames_so_far[-1]
    if not last_frame.is_valid_frame:
        return frames_so_far
    parent_frame = last_frame.parent_frame()
    return read_frames(frames_so_far + [parent_frame])

def hmbt(args, from_tty):
    if len(args) > 1:
        print "syntax: hmbt [stack_frame_address]"
        return

    if len(args) == 1:
        top_frame_addr = get_ptr_val(gdb.parse_and_eval(args[0]))
        pc = None
    elif  frame_pointer is not None:
        top_frame_addr = get_ptr_val(gdb.parse_and_eval(frame_pointer))
        pc = get_ptr_val(gdb.parse_and_eval("$pc"))
    else:
        raise RuntimeError('hmbt needs a stack frame address on this platform')

    inferior = gdb.selected_inferior()
    top_frame = Frame(top_frame_addr, pc=pc, inferior=inferior)
    for frame in read_frames([top_frame]):
        print frame

gdb_command("hmbt", hmbt)


class JSFrameInfoCommand(gdb.Command):
    def __init__(self, **kwargs):
        gdb.Command.__init__(self, "jsframeinfo", gdb.COMMAND_STACK, gdb.COMPLETE_EXPRESSION)
        self.inferior = gdb.selected_inferior()

    def read_word(self, addr):
        try:
            return gdb.Value(read_word(self.inferior, addr)).cast(VOIDP)
        except Exception, e:
            print "Got exception:", e, "when reading from:", hex(addr)
            return 0xabadcafe

    def invoke(self, arguments, from_tty):
        args = gdb.string_to_argv(arguments)
        if len(args) != 1:
            print "syntax: jsframeinfo [stack_frame_address]"
            return
        try:
            frame_addr = get_ptr_val(gdb.parse_and_eval(args[0]))
        except Exception, e:
            print "Could not get frame address for ", hex(frame_addr), "error:", e

        try:
            frame = Frame(frame_addr)
        except Exception, e:
            print "could not create frame at", hex(frame_addr), ":", e
            import pdb; pdb.set_trace()

        if not frame.is_valid_frame:
            print "This frame looks invalid"
            return

        print frame.long_str()


JSFrameInfoCommand()



#gdb_break("JSC::JITCode::execute")
#gdb_break("JSC::operationOptimize")
#gdb_break("JSC::JIT::emitSlow_op_loop_hint")
#gdb_break("JSC::JIT::privateCompile")
#gdb_break("JSC::DFG::Disassembler::dumpHeader")
#gdb_break("JSC::LLInt::CLoop::CLoop")
#gdb_break("JSC::LLInt::CLoop::initialize")
#gdb_break("JSC::LLInt::CLoop::execute")
#gdb_break("llint_entry")
#gdb_break(MemoryAddress(0x75db6ccc))

#gdb_break("JSC::DFG::operationPutByValWithThisStrict")
#gdb_break("DFGSpeculativeJIT32_64.cpp:2930")
#gdb_break("Executable.h:331")
#gdb_break("DFGSpeculativeJIT32_64.cpp:4956")
#gdb_break("DFGSpeculativeJIT32_64.cpp:4896")
