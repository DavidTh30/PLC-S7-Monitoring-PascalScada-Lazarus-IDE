"""Simulated Siemens S7 PLC for testing PLCMonitor.

DB1.DBD0  Real  Speed   : 750 + 600*sin(t/5)
DB1.DBW4  Int   Temp    : ramps 20..80 and back
M10.3     Bool  Running : toggles every 3 s
Stops by itself after RUN_SECONDS.
"""
import math
import struct
import sys
import time

import snap7
from snap7.type import SrvArea

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 102
RUN_SECONDS = int(sys.argv[2]) if len(sys.argv) > 2 else 600

# bytearrays are registered by reference (snap7 3.x copies ctypes arrays)
db1 = bytearray(32)
mk = bytearray(32)

srv = snap7.server.Server(log=False)
srv.register_area(SrvArea.DB, 1, db1)
srv.register_area(SrvArea.MK, 0, mk)
srv.start(tcp_port=PORT)
print(f"sim PLC listening on port {PORT}", flush=True)

t0 = time.time()
try:
    while time.time() - t0 < RUN_SECONDS:
        t = time.time() - t0
        speed = 750 + 600 * math.sin(t / 5)
        temp = int(50 + 30 * math.sin(t / 15))
        running = int(t // 3) % 2
        srv.lock_area(SrvArea.DB, 1)
        struct.pack_into(">f", db1, 0, speed)   # S7 is big endian
        struct.pack_into(">h", db1, 4, temp)
        srv.unlock_area(SrvArea.DB, 1)
        srv.lock_area(SrvArea.MK, 0)
        mk[10] = (mk[10] & ~0x08) | (0x08 if running else 0)
        srv.unlock_area(SrvArea.MK, 0)
        time.sleep(0.1)
finally:
    srv.stop()
    srv.destroy()
    print("sim PLC stopped", flush=True)
