import gdb
import os

if os.environ.get("KERNEL_DEBUG"):
    gdb.execute("set serial baud 115200")
    gdb.execute("set disassemble-next-line on")
    gdb.execute("b do_init_module")
