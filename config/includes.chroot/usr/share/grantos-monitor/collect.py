#!/usr/bin/env python3
"""GrantOS System Monitor collector.

Samples sensors + the process table once per second and writes JSON to
/run/user/<uid>/grantos-monitor.json (and /tmp fallback) for the QML
overlay. Also serves a localhost-only control endpoint so the UI can
end tasks (QML cannot spawn processes itself):

    POST http://127.0.0.1:47823/kill?pid=N&sig=15

Stdlib only. SPDX-License-Identifier: MIT
"""
import glob
import json
import os
import re
import shutil
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

UID = os.getuid()
PATHS = [f"/run/user/{UID}/grantos-monitor.json", "/tmp/grantos-monitor.json"]
HZ = os.sysconf("SC_CLK_TCK")
PORT = 47823


def read(path):
    try:
        with open(path) as fh:
            return fh.read()
    except OSError:
        return ""


def hwmon_temp(names):
    for h in glob.glob("/sys/class/hwmon/hwmon*/"):
        if read(h + "name").strip() in names:
            for p in ("temp1_input", "temp2_input"):
                v = read(h + p).strip()
                if v.isdigit() or (v.startswith("-") and v[1:].isdigit()):
                    return round(int(v) / 1000)
    return None


def gpu():
    """(load, temp, fan, vram_used, vram_total, core_clk, mem_clk, power)."""
    smi = shutil.which("nvidia-smi")
    if smi:
        try:
            out = subprocess.check_output(
                [smi, "--query-gpu=utilization.gpu,temperature.gpu,fan.speed,"
                     "memory.used,memory.total,clocks.sm,clocks.mem,power.draw",
                 "--format=csv,noheader,nounits"], text=True, timeout=2)
            f = [x.strip() for x in out.splitlines()[0].split(",")]

            def num(s):
                try:
                    return round(float(s), 1)
                except ValueError:
                    return None
            return dict(load=num(f[0]), temp=num(f[1]), fan=num(f[2]),
                        vramUsed=num(f[3]), vramTotal=num(f[4]),
                        coreClk=num(f[5]), memClk=num(f[6]), power=num(f[7]))
        except Exception:
            pass
    for dev in sorted(glob.glob("/sys/class/drm/card?/device")):
        busy = read(dev + "/gpu_busy_percent").strip()
        if not busy.isdigit():
            continue
        vu = read(dev + "/mem_info_vram_used").strip()
        vt = read(dev + "/mem_info_vram_total").strip()
        pw = None
        for p in glob.glob(dev + "/hwmon/hwmon*/power1_input"):
            v = read(p).strip()
            if v.isdigit():
                pw = round(int(v) / 1000000, 1)
                break
        temp = None
        for p in glob.glob(dev + "/hwmon/hwmon*/temp1_input"):
            v = read(p).strip()
            if v.isdigit():
                temp = round(int(v) / 1000)
                break
        return dict(load=int(busy), temp=temp, fan=None,
                    vramUsed=round(int(vu) / 2**30, 1) if vu.isdigit() else None,
                    vramTotal=round(int(vt) / 2**30, 1) if vt.isdigit() else None,
                    coreClk=None, memClk=None, power=pw)
    return {}


class KillHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        q = parse_qs(urlparse(self.path).query)
        code, msg = 400, b"bad request"
        try:
            os.kill(int(q["pid"][0]), int(q.get("sig", ["15"])[0]))
            code, msg = 200, b"ok"
        except (KeyError, ValueError, ProcessLookupError, PermissionError):
            pass
        self.send_response(code)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(msg)

    def log_message(self, *args):
        pass


def cpu_sample():
    cores, tot = [], None
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        p = line.split()
        idle = int(p[5]) + int(p[6])
        total = sum(int(x) for x in p[1:9])
        if p[0] == "cpu":
            tot = (total, idle)
        else:
            cores.append((total, idle))
    return tot, cores


def pct(prev, cur):
    if prev is None or cur[0] == prev[0]:
        return 0.0
    return max(0.0, min(100.0, 100 * (1 - (cur[1] - prev[1]) / (cur[0] - prev[0])))
               )


def proc_sample():
    """pid -> (ticks, name, rss_kb)"""
    out = {}
    me = os.getpid()
    for d in glob.glob("/proc/[0-9]*"):
        pid = int(d.rsplit("/", 1)[1])
        if pid == me:
            continue
        stat = read(d + "/stat")
        m = re.match(r"(\d+) \((.*)\) \S (.*)", stat, re.S)
        if not m:
            continue
        f = m.group(3).split()
        try:
            ticks = int(f[11]) + int(f[12])
        except (IndexError, ValueError):
            continue
        rss = 0
        for line in read(d + "/status").splitlines():
            if line.startswith("VmRSS:"):
                rss = int(line.split()[1])
                break
        out[pid] = (ticks, m.group(2), rss)
    return out


def main():
    threading.Thread(target=HTTPServer(("127.0.0.1", PORT), KillHandler).serve_forever,
                     daemon=True).start()
    prev_tot, prev_cores = None, None
    prev_t = {}
    prev_io = None
    last = time.time()
    while True:
        time.sleep(1)
        now = time.time()
        dt = max(now - last, 0.001)
        last = now

        tot, cores = cpu_sample()
        core_pcts = [round(pct(pc, cc)) for pc, cc in zip(prev_cores or cores, cores)]
        cpu = {"load": round(pct(prev_tot, tot)), "temp": hwmon_temp(
            {"k10temp", "coretemp", "zenpower", "cpu_thermal"}),
            "mhz": None, "cores": core_pcts}
        for line in read("/proc/cpuinfo").splitlines():
            if line.startswith("cpu MHz"):
                cpu["mhz"] = round(float(line.split(":")[1]))
                break

        mem = {}
        for line in read("/proc/meminfo").splitlines():
            if line.startswith("MemTotal:"):
                mem["total"] = round(int(line.split()[1]) / 2**20, 1)
            elif line.startswith("MemAvailable:"):
                mem["used"] = round((mem.get("total", 0) - int(line.split()[1]) / 2**20), 1)

        rr = ww = 0
        for line in read("/proc/diskstats").splitlines():
            p = line.split()
            if re.match(r"(sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+)$", p[2]):
                rr += int(p[5]) * 512
                ww += int(p[9]) * 512
        rx = tx = 0
        for d in glob.glob("/sys/class/net/*/statistics"):
            if d.endswith("/lo"):
                continue
            rx += int(read(d + "/rx_bytes") or 0)
            tx += int(read(d + "/tx_bytes") or 0)
        io = (rr, ww, rx, tx)
        pio = prev_io or io
        disk = {"read": round(max(0, rr - pio[0]) / 2**20 / dt, 1),
                "write": round(max(0, ww - pio[1]) / 2**20 / dt, 1)}
        net = {"rx": round(max(0, rx - pio[2]) * 8 / 1e6 / dt, 1),
               "tx": round(max(0, tx - pio[3]) * 8 / 1e6 / dt, 1)}
        prev_io = io

        cur = proc_sample()
        procs = []
        for pid, (ticks, name, rss) in cur.items():
            pprev = prev_t.get(pid)
            cpu_p = round(max(0.0, (ticks - pprev[0]) / HZ / dt * 100), 1) if pprev else 0.0
            procs.append({"pid": pid, "name": name, "cpu": cpu_p,
                          "mem": round(rss / 2**10, 1)})
        procs.sort(key=lambda p: (-p["cpu"], -p["mem"]))
        procs = procs[:80]
        prev_t = cur
        prev_tot, prev_cores = tot, cores

        data = {"time": time.strftime("%H:%M"), "gpu": gpu(), "cpu": cpu,
                "ram": mem or {"used": 0, "total": 1}, "disk": disk,
                "net": net, "processes": procs}
        blob = json.dumps(data, separators=(",", ":"))
        for p in PATHS:
            try:
                tmp = p + ".tmp"
                with open(tmp, "w") as fh:
                    fh.write(blob)
                os.replace(tmp, p)
            except OSError:
                pass


if __name__ == "__main__":
    main()
