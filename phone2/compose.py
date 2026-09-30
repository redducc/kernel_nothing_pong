#!/usr/bin/env python3
import glob, os, re, shutil, subprocess, sys

W = os.environ.get('PHONE2_WORK', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'work'))
D = os.environ.get('K66_DIST', os.path.expanduser('~/k66/out/nothing_pong/dist'))

def norm(n):
    return os.path.basename(n).replace('-', '_')

avail = {}
for p in sorted(glob.glob(D + '/*.ko')) + sorted(glob.glob(W + '/sysdlkm/flatten/lib/modules/*.ko')):
    avail.setdefault(norm(p), p)
gki = {norm(p) for p in glob.glob(W + '/sysdlkm/flatten/lib/modules/*.ko')}

deps = {}
for k, p in avail.items():
    out = subprocess.run(['modinfo', '-F', 'depends', p], capture_output=True, text=True).stdout.strip()
    deps[k] = [d.replace('-', '_') + '.ko' for d in out.split(',') if d]

# Hardware phone2 does not have, and test modules
EXCL = re.compile(r'^(bf_fp|dw3000|mcps802154|focaltech_ft3519|focaltech_fts|st21nfc|st54spi|.*_test|.*kunit.*|test_.*|soc_topology_test|.*_selftest)')

def read(p):
    return [l.strip() for l in open(p) if l.strip() and not l.startswith('#')]

def mapped(names, what):
    res, miss = [], []
    for n in names:
        k = norm(n)
        (res if k in avail else miss).append(k)
    print(f'{what}: {len(res)} mapped, missing: {" ".join(miss)}', file=sys.stderr)
    return res

def closure(order):
    seen, out = set(), []
    def visit(k):
        if k in seen or k not in avail:
            return
        seen.add(k)
        for d in deps[k]:
            visit(d)
        out.append(k)
    for k in order:
        visit(k)
    return out

SUBST_FS = ['pinctrl_waipio.ko', 'phy_qcom_ufs_qmp_v4_cape.ko', 'phy_qcom_ufs.ko', 'ufs_qcom.ko',
            'ufshcd_crypto_qti.ko', 'qnoc_waipio.ko', 'qcom_pmu_lib.ko', 'i2c_msm_geni.ko', 'spi_msm_geni.ko',
            'qcom_cpucp.ko', 'qcom_rng.ko', 'memory_dump_v2.ko', 'mem_offline.ko']

fs = closure(mapped(read(W + '/ref/fs.load'), 'first-stage') + SUBST_FS)
rec = closure(fs + mapped(read(W + '/ref/rec.load'), 'recovery'))
fs_set = set(fs)

NOTHING = ['hardware_id.ko', 'secure_state.ko', 'slot_status.ko', 'leds_aw20036.ko', 'haptic.ko',
           'goodix_fp.ko', 'goodix_core.ko', 'fts_tp.ko', 'simulated_ntc.ko', 'nothing_bootloader_log.ko',
           'nothing_restart_handler.ko', 'nothing_secure_element.ko', 'nothing_task_meminfo.ko', 'tfa98xx_dlkm.ko']
# Built into the 5.10 GKI kernel but modules on 6.6; the ROM's system_dlkm is still 5.10,
# so ship them here (netmgrd needs AF_TIPC)
GKI_WAS_BUILTIN = ['tipc.ko', 'bluetooth.ko', 'hci_uart.ko', 'btsdio.ko', 'hidp.ko', 'rfcomm.ko',
                   '6lowpan.ko', 'can.ko', 'can_raw.ko', 'ieee802154.ko', 'ieee802154_6lowpan.ko',
                   'mac802154.ko', 'l2tp_core.ko', 'l2tp_ppp.ko', 'ppp_generic.ko', 'bsd_comp.ko',
                   'ppp_deflate.ko', 'ppp_mppe.ko', 'pppox.ko', 'pptp.ko', 'usbnet.ko', 'cdc_eem.ko',
                   'aqc111.ko', 'rtl8150.ko', 'r8152.ko', 'cdc_acm.ko', 'nfc.ko', 'xhci_pci_renesas.ko']
vd_order = mapped(read(W + '/vdlkm_stock/lib/modules/modules.load'), 'vendor_dlkm') + NOTHING + GKI_WAS_BUILTIN
rest = sorted(k for k in avail if k not in gki and not EXCL.match(k))
vd = [k for k in closure(vd_order + rest) if k not in fs_set and not EXCL.match(k)]
# vendor_modprobe.sh only sets vendor.all.modules.ready if the first module loads
vd = ['zsmalloc.ko'] + [k for k in vd if k != 'zsmalloc.ko']

# Ship these but leave them out of the load lists, e.g. to insmod a crashing module by hand
NOLOAD = set(os.environ.get('NOLOAD', '').split())

def stage(root, mods, prefix, load, extra_loads):
    load = [k for k in load if k not in NOLOAD]
    extra_loads = {fn: [k for k in lst if k not in NOLOAD] for fn, lst in extra_loads.items()}
    moddir = os.path.join(root, 'lib/modules')
    shutil.rmtree(moddir, ignore_errors=True)
    rel = '6.6.0-staging'
    tmp = os.path.join(W, 'depmod-' + os.path.basename(root))
    shutil.rmtree(tmp, ignore_errors=True)
    tdir = os.path.join(tmp, 'lib/modules', rel)
    os.makedirs(tdir)
    os.makedirs(moddir)
    for k in mods:
        dst = os.path.basename(avail[k])
        shutil.copy2(avail[k], os.path.join(moddir, dst))
        shutil.copy2(avail[k], os.path.join(tdir, dst))
    subprocess.run(['depmod', '-b', tmp, rel], check=True)
    for f in ('modules.dep', 'modules.alias', 'modules.softdep'):
        s = open(os.path.join(tdir, f)).read()
        if f == 'modules.dep':
            s = re.sub(r'(^|\s)([^\s:]+\.ko)', lambda m: m.group(1) + prefix + os.path.basename(m.group(2)), s, flags=re.M)
        open(os.path.join(moddir, f), 'w').write(s)
    name = {k: os.path.basename(avail[k]) for k in avail}
    open(os.path.join(moddir, 'modules.load'), 'w').write(''.join(name[k] + '\n' for k in load))
    for fn, lst in extra_loads.items():
        open(os.path.join(moddir, fn), 'w').write(''.join(name[k] + '\n' for k in lst))
    return name

which = sys.argv[1]
if which == 'ramdisk':
    stage(W + '/vr', rec, '/lib/modules/', fs, {'modules.load.recovery': rec})
    shutil.copy2(W + '/stock_blocklist_vr', W + '/vr/lib/modules/modules.blocklist')
else:
    stage(W + '/vdlkm', vd, '/vendor/lib/modules/', vd, {})
    shutil.copy2(W + '/stock_blocklist_vd', W + '/vdlkm/lib/modules/modules.blocklist')
print(f'first-stage {len(fs)}, recovery {len(rec)}, vendor_dlkm {len(vd)}', file=sys.stderr)
