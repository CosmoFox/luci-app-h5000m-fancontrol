import sys, struct

BS = chr(92)

def sfh_get16(d, i):
    return d[i] | (d[i+1] << 8)

def s8(b):
    return b - 256 if b > 127 else b

def sfh_hash(data, initval=None):
    # po2lmo calls sfh_hash(data, len, len): initval defaults to len
    if initval is None:
        initval = len(data)
    h = initval & 0xffffffff
    rem = len(data) & 3
    n = len(data) >> 2
    i = 0
    for _ in range(n):
        h = (h + sfh_get16(data, i)) & 0xffffffff
        tmp = ((sfh_get16(data, i+2) << 11) ^ h) & 0xffffffff
        h = ((h << 16) ^ tmp) & 0xffffffff
        i += 4
        h = (h + (h >> 11)) & 0xffffffff
    if rem == 3:
        h = (h + sfh_get16(data, i)) & 0xffffffff
        h ^= (h << 16) & 0xffffffff
        h ^= (s8(data[i+2]) << 18) & 0xffffffff
        h = (h + (h >> 11)) & 0xffffffff
    elif rem == 2:
        h = (h + sfh_get16(data, i)) & 0xffffffff
        h ^= (h << 11) & 0xffffffff
        h = (h + (h >> 17)) & 0xffffffff
    elif rem == 1:
        h = (h + s8(data[i])) & 0xffffffff
        h ^= (h << 10) & 0xffffffff
        h = (h + (h >> 1)) & 0xffffffff
    h ^= (h << 3) & 0xffffffff
    h = (h + (h >> 5)) & 0xffffffff
    h ^= (h << 4) & 0xffffffff
    h = (h + (h >> 17)) & 0xffffffff
    h ^= (h << 25) & 0xffffffff
    h = (h + (h >> 6)) & 0xffffffff
    return h & 0xffffffff

def extract_string(line):
    # po2lmo extract_string: take text between first pair of quotes,
    # unescape only \" and \\ (other escapes stay literal)
    if line.startswith('#'):
        return None
    start = line.find('"')
    if start < 0:
        return None
    out = []
    esc = False
    for ch in line[start+1:]:
        if esc:
            if ch in ('"', BS):
                pass  # drop the backslash
            else:
                out.append(BS)
            out.append(ch)
            esc = False
        elif ch == BS:
            esc = True
        elif ch == '"':
            return ''.join(out)
        else:
            out.append(ch)
    return ''.join(out)

def parse_po_messages(path):
    # returns list of (msgid, msgstr) plus the raw header string
    msgs = []
    header = None
    cur = None   # (id, val, plural_num)
    buf_id = None
    buf_val = None
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n').rstrip('\r')
        if line.startswith('msgid "') or line.startswith('msgid_plural "') or line.startswith('msgstr'):
            pass
        if line.startswith('msgid "') :
            if buf_id is not None:
                msgs.append((buf_id, buf_val))
            buf_id = extract_string(line)
            buf_val = None
        elif line.startswith('msgstr'):
            if buf_id is not None and buf_val is None:
                buf_val = extract_string(line)
        elif line.startswith('"'):
            # continuation of msgstr (multi-line) - rare; append
            if buf_id is not None and buf_val is not None:
                s = extract_string(line)
                if s:
                    buf_val += s
    if buf_id is not None:
        msgs.append((buf_id, buf_val))
    if msgs and msgs[0][0] == '':
        header = msgs[0][1] or ''
        msgs = msgs[1:]
    return [(k, v) for k, v in msgs if k and v], header

def build_lmo(entries, header, out_path):
    items = []
    blob = bytearray()
    offset = 0
    for mid, mstr in entries:
        key = mid.encode('utf-8')
        val = mstr.encode('utf-8')
        key_id = sfh_hash(key, len(key))
        val_hash = sfh_hash(val, len(val))
        if key_id == val_hash:
            continue
        pad = (4 - (len(val) % 4)) % 4
        items.append((key_id, 1, offset, len(val)))
        blob += val + b'\x00' * pad
        offset += len(val) + pad
    # plural formula entry (key_id 0), like po2lmo
    if header:
        idx = header.lower().find('plural-forms: ')
        if idx >= 0:
            field = header[idx + 14:]
            val = field.encode('utf-8')
            pad = (4 - (len(val) % 4)) % 4
            items.append((0, 0, offset, len(val)))
            blob += val + b'\x00' * pad
            offset += len(val) + pad
    items.sort(key=lambda x: x[0])
    out = bytearray(blob)
    for k, v, o, l in items:
        out += struct.pack('>IIII', k, v, o, l)
    out += struct.pack('>I', offset)
    open(out_path, 'wb').write(bytes(out))
    return len(items), len(out)

if __name__ == '__main__':
    po_path, out_path = sys.argv[1], sys.argv[2]
    entries, header = parse_po_messages(po_path)
    n, size = build_lmo(entries, header, out_path)
    print('built %s: entries=%d size=%d header_plural=%s' % (out_path, n, size, bool(header and 'lural-forms' in header)))
