#!/usr/bin/env python3
"""Numbers for the Stats widget, printed as one JSON object.

  host     GPUs and disks. NVIDIA cards come from nvidia-smi; AMD (and
           anything else the kernel exposes) from /sys/class/drm. Disks come
           from lsblk, with usage read by statvfs on one mountpoint per
           filesystem — lsblk leaves FSUSED empty for a btrfs volume mounted
           many times (subvolumes, kubelet bind mounts). CPU and RAM are read
           by the shell itself: CPU usage needs the delta between two polls.

  kube     Nodes, pods and `kubectl top` for a local Kubernetes cluster.
           Which cluster is set in ../local.json (see local.example.json):

             stats.kubeconfig   default: $KUBECONFIG, else ~/.kube/config
             stats.context      default: the current context if its API
                                server is on this machine, else the first
                                context in the file that is

           Without an explicit context only loopback API servers
           (127.0.0.0/8, ::1, localhost) are ever contacted, so a kubeconfig
           that also holds remote (e.g. work) clusters is never polled by
           accident. Naming a context trusts it, for setups like minikube
           whose API server sits on a VM address.

  mount DEVICE / eject DISK
           Mount a partition, or unmount a disk's partitions and power it
           off, through udisksctl (as the user; polkit asks if it must).

Each section carries `ok` and, when not ok, `error` (a short line for the
widget). A kube section that needs configuring also carries `setup: true`.

Usage: system-stats.py host | kube | mount DEVICE | eject DISK
"""
import glob
import ipaddress
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
LOCAL_CONFIG = os.path.join(os.path.dirname(HERE), "local.json")
KUBE_TIMEOUT = 6

# Mounts that are never the one to show for a filesystem.
NOISE_MOUNTS = ("/var/lib/kubelet/", "/var/lib/docker/", "/var/lib/containers/", "/snap/")


def run(cmd, timeout=5):
    """(returncode, stdout, stderr); 127 when the program is missing."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr.strip()
    except FileNotFoundError:
        return 127, "", cmd[0] + " is not installed"
    except subprocess.TimeoutExpired:
        return 124, "", cmd[0] + " timed out"


def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def local_config():
    try:
        with open(LOCAL_CONFIG) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as e:
        raise ValueError("local.json is not valid JSON: " + str(e))


# ── GPUs ────────────────────────────────────────────────────────────────────

def nvidia_gpus():
    code, out, _ = run(["nvidia-smi",
                        "--query-gpu=pci.bus_id,name,utilization.gpu,memory.used,memory.total,temperature.gpu",
                        "--format=csv,noheader,nounits"])
    gpus = []
    if code != 0:
        return gpus
    for line in out.splitlines():
        f = [x.strip() for x in line.split(",")]
        if len(f) < 6:
            continue

        def num(s):
            try:
                return float(s)
            except ValueError:
                return None
        gpus.append({
            "bus": f[0].lower()[-12:],        # "0000:01:00.0", matches sysfs
            "name": f[1].replace("NVIDIA ", "").replace("GeForce ", ""),
            "vendor": "nvidia",
            "percent": num(f[2]),
            "vram_used": (num(f[3]) or 0) * 1048576,
            "vram_total": (num(f[4]) or 0) * 1048576,
            "temp": num(f[5]),
        })
    return gpus


def sysfs_gpus(skip_buses):
    gpus = []
    for card in sorted(glob.glob("/sys/class/drm/card[0-9]*")):
        if "-" in os.path.basename(card):     # connectors: card1-DP-1
            continue
        dev = os.path.join(card, "device")
        bus = os.path.basename(os.path.realpath(dev)).lower()
        if bus in skip_buses:
            continue
        vendor = {"0x1002": "amd", "0x8086": "intel", "0x10de": "nvidia"}.get(read(dev + "/vendor"), "other")
        busy = read(dev + "/gpu_busy_percent")
        vram_total = int(read(dev + "/mem_info_vram_total", "0") or 0)
        vram_used = int(read(dev + "/mem_info_vram_used", "0") or 0)
        temp = None
        for t in glob.glob(dev + "/hwmon/hwmon*/temp1_input"):
            temp = int(read(t, "0")) / 1000
            break
        name = read(dev + "/product_name")
        if not name:
            # APUs report a small carve-out as VRAM; that's the tell.
            name = {"amd": "Radeon", "intel": "Intel Graphics", "nvidia": "NVIDIA GPU"}.get(vendor, "GPU")
            if vendor == "amd" and 0 < vram_total < 4 * 1024 ** 3:
                name += " (integrated)"
        gpus.append({
            "bus": bus,
            "name": name,
            "vendor": vendor,
            "percent": float(busy) if busy not in (None, "") else None,   # Intel: no counter without root
            "vram_used": vram_used,
            "vram_total": vram_total,
            "temp": temp,
        })
    return gpus


def gpus():
    nv = nvidia_gpus()
    found = nv + sysfs_gpus({g["bus"] for g in nv})
    # Busiest-looking first: discrete (most VRAM) leads.
    found.sort(key=lambda g: -g["vram_total"])
    return found


# ── CPU extras (usage itself is computed in the shell) ──────────────────────

def cpu_info():
    model = ""
    for line in (read("/proc/cpuinfo", "") or "").splitlines():
        if line.startswith("model name"):
            model = line.split(":", 1)[1].strip()
            break
    for junk in ("(R)", "(TM)", " CPU", " Processor"):
        model = model.replace(junk, "")
    model = model.split(" @ ")[0]
    # "AMD Ryzen 7 9700X 8-Core" → "AMD Ryzen 7 9700X"
    model = " ".join(w for w in model.split() if not w.endswith("-Core"))

    temp = None
    for hw in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(hw + "/name") in ("k10temp", "coretemp", "zenpower"):
            temp = int(read(hw + "/temp1_input", "0") or 0) / 1000
            break
    return {"model": model, "threads": os.cpu_count() or 0, "temp": temp}


# ── Disks ───────────────────────────────────────────────────────────────────

def primary_mount(mounts):
    mounts = [m for m in mounts or [] if m and m != "[SWAP]"
              and not m.startswith(NOISE_MOUNTS)]
    return min(mounts, key=len) if mounts else None


def usage(mount):
    try:
        st = os.statvfs(mount)
    except OSError:
        return None, None
    total = st.f_blocks * st.f_frsize
    return total - st.f_bfree * st.f_frsize, total


def filesystems(node):
    """The filesystems on a disk: partitions, a disk formatted without a
    partition table, or what sits inside an unlocked LUKS / LVM container."""
    fstype = node.get("fstype")
    if fstype and fstype not in ("swap", "crypto_LUKS", "LVM2_member"):
        return [node]
    found = []
    for c in node.get("children") or []:
        found.extend(filesystems(c))
    return found


def disks():
    code, out, err = run(["lsblk", "-J", "-b", "-o",
                          "NAME,PATH,TYPE,SIZE,FSTYPE,MOUNTPOINTS,RM,HOTPLUG,TRAN,LABEL,MODEL,VENDOR"])
    if code != 0:
        raise RuntimeError(err or "lsblk failed")

    result = []
    for d in json.loads(out).get("blockdevices", []):
        if d.get("type") != "disk" or d["name"].startswith(("zram", "loop", "ram")):
            continue
        parts = []
        for p in filesystems(d):
            mount = primary_mount(p.get("mountpoints"))
            used, total = usage(mount) if mount else (None, None)
            parts.append({
                "path": p["path"],
                "label": p.get("label") or "",
                "fstype": p.get("fstype") or "",
                "size": p.get("size") or 0,
                "mount": mount,
                "used": used,
                "total": total,
            })
        if not parts:
            continue
        external = bool(d.get("hotplug") or d.get("rm") or d.get("tran") == "usb")
        mounted = [p for p in parts if p["mount"]]
        labels = [p["label"] for p in parts if p["label"]]
        result.append({
            "path": d["path"],
            "name": d["name"],
            "model": " ".join(filter(None, [(d.get("vendor") or "").strip() if external else "",
                                            (d.get("model") or "").strip()])) or d["name"],
            "label": labels[0] if labels else "",
            "tran": d.get("tran") or "",
            "size": d.get("size") or 0,
            "external": external,
            "parts": parts,
            "mounts": [p["mount"] for p in mounted],
            "used": sum(p["used"] or 0 for p in mounted),
            "total": sum(p["total"] or 0 for p in mounted),
        })
    # Internal: the one holding / first. External: in plug order (by name).
    result.sort(key=lambda d: (d["external"], "/" not in d["mounts"], d["name"]))
    return result


def host():
    out = {"ok": True}
    try:
        out["cpu"] = cpu_info()
        out["gpus"] = gpus()
        out["disks"] = disks()
    except Exception as e:  # one bad read shouldn't blank the widget
        out.update(ok=False, error=str(e))
    return out


# ── Kubernetes ──────────────────────────────────────────────────────────────

def is_local_server(server):
    host = (urlparse(server).hostname or "").lower()
    if host == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def kube_target(cfg):
    """(kubeconfig, context, server) or raise KubeSetup with the reason."""
    env = (os.environ.get("KUBECONFIG") or "").split(os.pathsep)[0]
    kubeconfig = os.path.expanduser(cfg.get("kubeconfig") or env or "~/.kube/config")
    wanted = cfg.get("context") or ""

    if not os.path.exists(kubeconfig):
        raise KubeSetup("No kubeconfig at " + kubeconfig.replace(os.path.expanduser("~"), "~"))

    code, out, err = run(["kubectl", "config", "view", "--kubeconfig", kubeconfig, "-o", "json"])
    if code == 127:
        raise KubeSetup("kubectl is not installed")
    if code != 0:
        raise KubeSetup("Can't read " + kubeconfig + ": " + err)
    view = json.loads(out)
    servers = {c["name"]: c.get("cluster", {}).get("server", "") for c in view.get("clusters") or []}
    contexts = {c["name"]: servers.get(c.get("context", {}).get("cluster"), "")
                for c in view.get("contexts") or []}

    if wanted:
        if wanted not in contexts:
            raise KubeSetup("No context \"" + wanted + "\" in " + kubeconfig)
        return kubeconfig, wanted, contexts[wanted]

    current = view.get("current-context") or ""
    if current in contexts and is_local_server(contexts[current]):
        return kubeconfig, current, contexts[current]
    for name, server in contexts.items():
        if is_local_server(server):
            return kubeconfig, name, server
    raise KubeSetup("No local cluster in " + kubeconfig.replace(os.path.expanduser("~"), "~")
                    + (" (" + str(len(contexts)) + " remote context" + ("s" if len(contexts) != 1 else "") + ")"
                       if contexts else ""))


class KubeSetup(Exception):
    pass


def quantity_cores(s):
    """"705m" → 0.705, "2" → 2."""
    return float(s[:-1]) / 1000 if s.endswith("m") else float(s)


def quantity_bytes(s):
    units = {"Ki": 1024, "Mi": 1024 ** 2, "Gi": 1024 ** 3, "Ti": 1024 ** 4,
             "k": 1e3, "M": 1e6, "G": 1e9, "T": 1e12}
    for u in sorted(units, key=len, reverse=True):
        if s.endswith(u):
            return float(s[:-len(u)]) * units[u]
    return float(s)


BAD_WAITING = {"CrashLoopBackOff", "ImagePullBackOff", "ErrImagePull", "CreateContainerConfigError",
               "InvalidImageName", "RunContainerError"}


def pod_problem(pod):
    """Short reason a pod needs attention, or None."""
    status = pod.get("status", {})
    phase = status.get("phase")
    if phase == "Succeeded":
        return None
    for c in (status.get("initContainerStatuses") or []) + (status.get("containerStatuses") or []):
        reason = (c.get("state", {}).get("waiting") or {}).get("reason")
        if reason in BAD_WAITING:
            return reason
    if phase in ("Pending", "Failed", "Unknown"):
        return status.get("reason") or phase
    return None


def kube():
    try:
        cfg = local_config().get("stats") or {}
        kubeconfig, context, server = kube_target(cfg)
    except (KubeSetup, ValueError) as e:
        return {"ok": False, "setup": True, "error": str(e), "config": LOCAL_CONFIG}

    base = ["kubectl", "--kubeconfig", kubeconfig, "--context", context,
            "--request-timeout=" + str(KUBE_TIMEOUT - 1) + "s"]
    calls = {
        "nodes": base + ["get", "nodes", "-o", "json"],
        "pods": base + ["get", "pods", "-A", "-o", "json"],
        "top_nodes": base + ["top", "nodes", "--no-headers"],
    }
    with ThreadPoolExecutor(len(calls)) as pool:
        futures = {k: pool.submit(run, v, KUBE_TIMEOUT) for k, v in calls.items()}
        res = {k: f.result() for k, f in futures.items()}

    head = {"context": context, "server": server, "kubeconfig": kubeconfig}
    code, out, err = res["nodes"]
    if code != 0:
        line = (err.splitlines() or ["kubectl failed"])[-1]
        if "connection refused" in line or "dial tcp" in line:
            line = "Cluster unreachable at " + server + " — is it running?"
        return dict(head, ok=False, error=line)

    nodes = {}
    for n in json.loads(out).get("items", []):
        conds = {c["type"]: c["status"] for c in n.get("status", {}).get("conditions", [])}
        alloc = n.get("status", {}).get("allocatable", {})
        nodes[n["metadata"]["name"]] = {
            "name": n["metadata"]["name"],
            "ready": conds.get("Ready") == "True",
            "cores": quantity_cores(alloc.get("cpu", "0")),
            "memory": quantity_bytes(alloc.get("memory", "0")),
            "cpu": None, "mem": None,
        }

    metrics = res["top_nodes"][0] == 0
    if metrics:
        for line in res["top_nodes"][1].splitlines():
            f = line.split()
            if len(f) >= 5 and f[0] in nodes:
                nodes[f[0]]["cpu"] = float(f[2].rstrip("%")) if f[2] != "<unknown>" else None
                nodes[f[0]]["mem"] = float(f[4].rstrip("%")) if f[4] != "<unknown>" else None

    pods = {"total": 0, "running": 0, "pending": 0, "failed": 0, "succeeded": 0}
    problems = 0
    if res["pods"][0] == 0:
        for p in json.loads(res["pods"][1]).get("items", []):
            phase = (p.get("status", {}).get("phase") or "Unknown").lower()
            pods["total"] += 1
            if phase in pods:
                pods[phase] += 1
            if pod_problem(p):
                problems += 1

    return dict(head, ok=True, metrics=metrics, nodes=list(nodes.values()), pods=pods,
                problem_count=problems)


# ── Actions ─────────────────────────────────────────────────────────────────

def action(verb, device):
    if verb == "mount":
        code, _, err = run(["udisksctl", "mount", "--no-user-interaction", "-b", device], timeout=30)
        if code != 0:   # retry letting polkit ask, for disks that need it
            code, _, err = run(["udisksctl", "mount", "-b", device], timeout=60)
        return {"ok": code == 0, "error": err if code else ""}

    # eject: unmount every mounted partition, then cut power.
    code, out, err = run(["lsblk", "-J", "-o", "PATH,MOUNTPOINTS", device])
    if code != 0:
        return {"ok": False, "error": err}
    todo = []

    def walk(n):
        if any(n.get("mountpoints") or []):
            todo.append(n["path"])
        for c in n.get("children") or []:
            walk(c)
    for n in json.loads(out).get("blockdevices", []):
        walk(n)
    for path in todo:
        code, _, err = run(["udisksctl", "unmount", "-b", path], timeout=60)
        if code != 0:
            return {"ok": False, "error": err.splitlines()[-1] if err else "unmount failed"}
    code, _, err = run(["udisksctl", "power-off", "-b", device], timeout=30)
    return {"ok": code == 0, "error": err if code else ""}


def main():
    args = sys.argv[1:] or ["host"]
    if args[0] in ("mount", "eject") and len(args) == 2:
        print(json.dumps(action(*args)))
    elif args[0] == "host":
        print(json.dumps(host()))
    elif args[0] == "kube":
        print(json.dumps(kube()))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
