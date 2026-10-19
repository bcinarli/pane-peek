import { execFileSync } from 'node:child_process';

const integer = value => { const bytes = Buffer.alloc(4); bytes.writeUInt32BE(value); return bytes; };
const text = value => Buffer.from(value, 'utf16le').swap16();
const plist = value => execFileSync('plutil', ['-convert', 'binary1', '-o', '-', '-'], { input: JSON.stringify(value), timeout: 10_000 });

/** Write the small, single-leaf Finder store needed by this fixed installer layout. */
export function diskImageLayout(bookmark) {
  const entries = [
    ['.', 'bwsp', 'blob', plist({ ShowStatusBar: false, ShowTabView: false, ShowToolbar: false, ShowSidebar: false,
      ShowPathbar: false, ContainerShowSidebar: false, WindowBounds: '{{180, 120}, {760, 482}}' })],
    ['.', 'icvp', 'blob', plist({ viewOptionsVersion: 1, backgroundType: 2, backgroundColorRed: 0.141, backgroundColorGreen: 0.153,
      backgroundColorBlue: 0.227, gridOffsetX: 0, gridOffsetY: 0, gridSpacing: 100, arrangeBy: 'none', showIconPreview: false,
      showItemInfo: false, labelOnBottom: true, textSize: 15, iconSize: 128, scrollPositionX: 0, scrollPositionY: 0 })],
    ['.', 'pBBk', 'blob', bookmark],
    ['.', 'vSrn', 'long', integer(1)],
    ['.', 'vstl', 'type', Buffer.from('icnv')],
    ['.background', 'Iloc', 'blob', Buffer.concat([integer(220), integer(620), integer(0xffffffff), integer(0xffff0000)])],
    ['.VolumeIcon.icns', 'Iloc', 'blob', Buffer.concat([integer(540), integer(620), integer(0xffffffff), integer(0xffff0000)])],
    ['Applications', 'Iloc', 'blob', Buffer.concat([integer(540), integer(230), integer(0xffffffff), integer(0xffff0000)])],
    ['PanePeek.app', 'Iloc', 'blob', Buffer.concat([integer(220), integer(230), integer(0xffffffff), integer(0xffff0000)])],
  ];
  const records = entries.map(([name, code, type, value]) => Buffer.concat([
    integer(name.length), text(name), Buffer.from(code + type), ...(type === 'blob' ? [integer(value.length)] : []), value,
  ]));
  const leaf = Buffer.concat([integer(0), integer(records.length), ...records]);
  if (leaf.length > 4096) { throw new Error('The fixed DMG layout exceeds its Finder metadata page.'); }

  // Finder uses a buddy allocator; offsets are relative to the four-byte file prefix.
  const freeLists = Array.from({ length: 32 }, () => []);
  freeLists[5] = [32, 96];
  for (let power = 7; power <= 10; power++) { freeLists[power] = [2 ** power]; }
  for (let power = 13; power <= 30; power++) { freeLists[power] = [2 ** power]; }
  const addresses = Buffer.alloc(1024);
  addresses.writeUInt32BE(2048 | 11, 0);
  addresses.writeUInt32BE(64 | 5, 4);
  addresses.writeUInt32BE(4096 | 12, 8);
  const bookkeeping = Buffer.concat([integer(3), integer(0), addresses, integer(1), Buffer.from([4]), Buffer.from('DSDB'), integer(1),
    ...freeLists.flatMap(offsets => [integer(offsets.length), ...offsets.map(integer)])]);
  const store = Buffer.alloc(8196);
  integer(1).copy(store);
  Buffer.concat([Buffer.from('Bud1'), integer(2048), integer(bookkeeping.length), integer(2048)]).copy(store, 4);
  Buffer.concat([integer(2), integer(0), integer(records.length), integer(1), integer(4096)]).copy(store, 68);
  bookkeeping.copy(store, 2052);
  leaf.copy(store, 4100);
  return store;
}
