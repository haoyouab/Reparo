import gdb


class DmesgCommand(gdb.Command):
    """Print kernel dmesg ring buffer (requires vmlinux symbols with lx-dmesg)."""

    def __init__(self):
        super().__init__("dmesg", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        try:
            gdb.execute("lx-dmesg")
        except gdb.error as e:
            print("dmesg failed (vmlinux symbols with lx- commands required): {}".format(e))


class LsmodCommand(gdb.Command):
    """List loaded kernel modules (requires vmlinux symbols with lx-lsmod)."""

    def __init__(self):
        super().__init__("lsmod", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        try:
            gdb.execute("lx-lsmod")
        except gdb.error as e:
            print("lsmod failed (vmlinux symbols with lx- commands required): {}".format(e))


class OffsetOfCommand(gdb.Command):
    """Print the offset of a field within a struct: offsetof <type> <field>"""

    def __init__(self):
        super().__init__("offsetof", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        args = arg.split()
        if len(args) != 2:
            print("Usage: offsetof <type> <field>")
            return
        type_name, field_name = args
        try:
            t = gdb.lookup_type(type_name)
            for f in t.fields():
                if f.name == field_name:
                    print("{}.{} offset = {} bytes".format(type_name, field_name, f.bitpos // 8))
                    return
            print("Field '{}' not found in '{}'".format(field_name, type_name))
        except gdb.error as e:
            print("offsetof failed: {}".format(e))


class ContainerOfCommand(gdb.Command):
    """Compute container_of: container_of <ptr> <type> <member>"""

    def __init__(self):
        super().__init__("container_of", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        args = arg.split()
        if len(args) != 3:
            print("Usage: container_of <ptr> <type> <member>")
            return
        ptr_expr, type_name, member_name = args
        try:
            ptr = gdb.parse_and_eval(ptr_expr)
            t = gdb.lookup_type(type_name)
            offset = None
            for f in t.fields():
                if f.name == member_name:
                    offset = f.bitpos // 8
                    break
            if offset is None:
                print("Field '{}' not found in '{}'".format(member_name, type_name))
                return
            container_addr = int(ptr) - offset
            result = gdb.Value(container_addr).cast(t.pointer())
            print("({} *) {}".format(type_name, result))
        except gdb.error as e:
            print("container_of failed: {}".format(e))


class EWatchCommand(gdb.Command):
    """Watch an expression in dashboard: ew <expr>"""

    def __init__(self):
        super().__init__("ew", gdb.COMMAND_USER, gdb.COMPLETE_EXPRESSION)

    def invoke(self, arg, from_tty):
        if not arg.strip():
            print("Usage: ew <expression>")
            return
        gdb.execute("dashboard expressions watch " + arg)


class EUnwatchCommand(gdb.Command):
    """Unwatch an expression: eu <expr>"""

    def __init__(self):
        super().__init__("eu", gdb.COMMAND_USER, gdb.COMPLETE_EXPRESSION)

    def invoke(self, arg, from_tty):
        if not arg.strip():
            print("Usage: eu <expression>")
            return
        gdb.execute("dashboard expressions unwatch " + arg)


class EClearCommand(gdb.Command):
    """Clear all watched expressions: ec"""

    def __init__(self):
        super().__init__("ec", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        gdb.execute("dashboard expressions clear")


DmesgCommand()
LsmodCommand()
OffsetOfCommand()
ContainerOfCommand()
EWatchCommand()
EUnwatchCommand()
EClearCommand()


def _remove_glib_objfile_printers(event):
    for obj in gdb.objfiles():
        obj.pretty_printers[:] = [
            pp for pp in obj.pretty_printers
            if getattr(pp, "__module__", "") not in ("glib_gdb", "gobject_gdb")
        ]

gdb.events.new_objfile.connect(_remove_glib_objfile_printers)
