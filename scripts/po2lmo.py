#!/usr/bin/env python3
# po -> lmo converter mirroring the official luci po2lmo.c exactly (same
# SuperFastHash keys, big-endian index, padding and untranslated-string
# skipping). Used to (re)generate the catalogs embedded into the main
# package under root/usr/lib/lua/luci/i18n/ and checked by check-lmo.sh.
import re, struct, sys

def sfh(d: bytes) -> int:
    """SuperFastHash with initval = len(d), as used by liblmo."""
    def get16(i): return d[i] | (d[i+1] << 8)
    n = len(d)
    h = n & 0xFFFFFFFF
    rem = n & 3
    n4 = n >> 2
    i = 0
    for _ in range(n4):
        h = (h + get16(i)) & 0xFFFFFFFF
        tmp = ((get16(i+2) << 11) ^ h) & 0xFFFFFFFF
        h = ((h << 16) ^ tmp) & 0xFFFFFFFF
        h = (h + (h >> 11)) & 0xFFFFFFFF
        i += 4
    if rem == 3:
        h = (h + get16(i)) & 0xFFFFFFFF
        h = (h ^ (h << 16)) & 0xFFFFFFFF
        h = (h ^ (d[i+2] << 18)) & 0xFFFFFFFF
        h = (h + (h >> 11)) & 0xFFFFFFFF
    elif rem == 2:
        h = (h + get16(i)) & 0xFFFFFFFF
        h = (h ^ (h << 11)) & 0xFFFFFFFF
        h = (h + (h >> 17)) & 0xFFFFFFFF
    elif rem == 1:
        h = (h + d[i]) & 0xFFFFFFFF
        h = (h ^ (h << 10)) & 0xFFFFFFFF
        h = (h + (h >> 1)) & 0xFFFFFFFF
    h = (h ^ (h << 3)) & 0xFFFFFFFF
    h = (h + (h >> 5)) & 0xFFFFFFFF
    h = (h ^ (h << 4)) & 0xFFFFFFFF
    h = (h + (h >> 17)) & 0xFFFFFFFF
    h = (h ^ (h << 25)) & 0xFFFFFFFF
    h = (h + (h >> 6)) & 0xFFFFFFFF
    return h

def po_unescape(s: str) -> str:
    # po2lmo drops the backslash only before " and \; other escapes stay literal.
    out, esc = [], False
    for ch in s:
        if esc:
            if ch in '"\\':
                out.append(ch)
            else:
                out.append('\\' + ch)
            esc = False
        elif ch == '\\':
            esc = True
        else:
            out.append(ch)
    if esc:
        out.append('\\')
    return ''.join(out)

def parse_po(path):
    """Return list of (msgid, [msgstr forms]) and the Plural-Forms string."""
    msgs = []
    cur = None  # dict: id, strs{}, ctxt, plural
    last = None
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if line.startswith('msgid_plural '):
            last = 'id_plural'
            continue
        m = re.match(r'msgid\s+"(.*)"$', line)
        if m:
            if cur is not None:
                msgs.append(cur)
            cur = {'id': po_unescape(m.group(1)), 'strs': {}, 'plural': False}
            last = 'id'
            continue
        m = re.match(r'msgstr\[(\d+)\]\s+"(.*)"$', line)
        if m:
            cur['strs'][int(m.group(1))] = po_unescape(m.group(2))
            cur['plural'] = True
            last = 'str'
            continue
        m = re.match(r'msgstr\s+"(.*)"$', line)
        if m:
            cur['strs'][0] = po_unescape(m.group(1))
            last = 'str'
            continue
        m = re.match(r'\s+"(.*)"$', line)
        if m and cur is not None and last:
            if last == 'id':
                cur['id'] += po_unescape(m.group(1))
            elif last == 'str':
                idx = max(cur['strs']) if cur['strs'] else 0
                cur['strs'][idx] = cur['strs'].get(idx, '') + po_unescape(m.group(1))
            continue
        if line.startswith('#') or not line.strip():
            last = None
    if cur is not None:
        msgs.append(cur)
    plural_forms = None
    for m in msgs:
        if m['id'] == '' and 0 in m['strs']:
            mm = re.search(r'Plural-Forms:\s*([^\\]+)', m['strs'][0])
            if mm:
                plural_forms = mm.group(1).strip()
    return msgs, plural_forms

def build_lmo(path):
    msgs, plural_forms = parse_po(path)
    data = bytearray()
    entries = []  # (key_id, val_id, offset, length)
    offset = 0
    if plural_forms:
        pf = plural_forms.encode('utf-8')
        entries.append((0, 0, offset, len(pf)))
        pad = (4 - len(pf) % 4) % 4
        data += pf + b'\0' * pad
        offset += len(pf) + pad
    for m in msgs:
        if not m['id'] or not m['strs']:
            continue  # header or untranslated block
        plural_num = max(m['strs']) if m['plural'] else 0
        for i in range(plural_num + 1):
            val = m['strs'].get(i)
            if not val:
                continue
            key = ('%s\2%d' % (m['id'], i)) if m['plural'] else m['id']
            kb, vb = key.encode('utf-8'), val.encode('utf-8')
            key_id, val_id = sfh(kb), sfh(vb)
            if key_id == val_id:
                continue  # untranslated (identical key and value)
            entries.append((key_id, plural_num + 1, offset, len(vb)))
            pad = (4 - len(vb) % 4) % 4
            data += vb + b'\0' * pad
            offset += len(vb) + pad
    entries.sort(key=lambda e: e[0])
    out = bytes(data)
    for key_id, val_id, off, ln in entries:
        out += struct.pack('>IIII', key_id, val_id, off, ln)
    out += struct.pack('>I', offset)
    return out

def read_lmo(path):
    """Parse an lmo file back: returns {key_id: (val_id, value)}."""
    blob = open(path, 'rb').read()
    data_len = struct.unpack_from('>I', blob, len(blob) - 4)[0]
    entries = {}
    pos = data_len
    while pos + 16 <= len(blob) - 4:
        key_id, val_id, off, ln = struct.unpack_from('>IIII', blob, pos)
        entries[key_id] = (val_id, blob[off:off+ln].decode('utf-8'))
        pos += 16
    return entries

if __name__ == '__main__':
    po_path, out_path = sys.argv[1], sys.argv[2]
    lmo = build_lmo(po_path)
    open(out_path, 'wb').write(lmo)

    # round-trip validation against the po
    msgs, _ = parse_po(po_path)
    cat = read_lmo(out_path)
    want = {}
    for m in msgs:
        if not m['id'] or not m['strs']:
            continue
        plural_num = max(m['strs']) if m['plural'] else 0
        for i in range(plural_num + 1):
            val = m['strs'].get(i)
            if not val:
                continue
            key = ('%s\2%d' % (m['id'], i)) if m['plural'] else m['id']
            kid = sfh(key.encode('utf-8'))
            if kid != sfh(val.encode('utf-8')):
                want[kid] = val
    got = {k: v for k, (vid, v) in cat.items() if k != 0}
    missing = {k: v for k, v in want.items() if k not in got}
    extra = {k: v for k, v in got.items() if k not in want}
    bad = {k: (v, got[k]) for k, v in want.items() if k in got and got[k] != v}
    print('entries: %d, want %d, missing %d, extra %d, mismatched %d' %
          (len(got), len(want), len(missing), len(extra), len(bad)))
    for k, v in list(missing.items())[:5]: print('  MISSING:', repr(v))
    for k, v in list(bad.items())[:5]: print('  BAD:', repr(v))
    sys.exit(1 if (missing or bad) else 0)
