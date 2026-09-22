import zlib, struct, sys

W, H = 88, 31
BG = (0, 0, 0, 255)
AMBER = (255, 201, 64, 255)
WHITE = (246, 242, 242, 255)
GREY = (200, 200, 200, 255)
BEVEL_L = (120, 120, 120, 255)
BEVEL_D = (60, 60, 60, 255)

px = [[BG for _ in range(W)] for _ in range(H)]

def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[y][x] = c

# bevel border: light top/left, dark bottom/right
for x in range(W):
    put(x, 0, BEVEL_L); put(x, H - 1, BEVEL_D)
for y in range(H):
    put(0, y, BEVEL_L); put(W - 1, y, BEVEL_D)

# cat face, 20x18. '#' fur (white on black bg -> we draw the cat in white? no: black cat on black bg is invisible)
# so: fur = dark grey outline? Better: draw the cat as a white silhouette with black eyes... but the app's cat is black.
# Solution: cat sits on an amber disc (like a highlighted sector). fur '#', eye white 'o', pupil 'p', disc '~'
CAT = [
"..##............##..",
".###............###.",
".####..........####.",
".#####........#####.",
".##################.",
"####################",
"####################",
"####################",
"###.oooo####oooo.###",
"###oooooo##oooooo###",
"###oopp.o##o.ppoo###",
"###oopp.o##o.ppoo###",
"###oooooo##oooooo###",
"####.oooo##oooo.####",
"####################",
".##################.",
"..################..",
"....############....",
]
CX, CY = 4, 6
# amber disc behind the cat
import math
for y in range(H):
    for x in range(W):
        if (x - (CX + 9.5)) ** 2 / (13.5 ** 2) + (y - (CY + 8.5)) ** 2 / (13.5 ** 2) <= 1:
            put(x, y, AMBER)
for j, row in enumerate(CAT):
    for i, ch in enumerate(row):
        if ch == '#': put(CX + i, CY + j, BG)
        elif ch == 'o': put(CX + i, CY + j, WHITE)
        elif ch == 'p': put(CX + i, CY + j, BG)

FONT = {
'A': [".###.","#...#","#...#","#####","#...#","#...#","#...#"],
'B': ["####.","#...#","#...#","####.","#...#","#...#","####."],
'C': [".###.","#...#","#....","#....","#....","#...#",".###."],
'F': ["#####","#....","#....","####.","#....","#....","#...."],
'G': [".###.","#...#","#....","#.###","#...#","#...#",".####"],
'M': ["#...#","##.##","#.#.#","#.#.#","#...#","#...#","#...#"],
'O': [".###.","#...#","#...#","#...#","#...#","#...#",".###."],
'R': ["####.","#...#","#...#","####.","#.#..","#..#.","#...#"],
'S': [".####","#....","#....",".###.","....#","....#","####."],
'T': ["#####","..#..","..#..","..#..","..#..","..#..","..#.."],
' ': [".....",".....",".....",".....",".....",".....","....."],
}

def text(x, y, s, c):
    for ch in s:
        g = FONT[ch]
        for j, row in enumerate(g):
            for i, v in enumerate(row):
                if v == '#': put(x + i, y + j, c)
        x += 6

text(34, 7, "CATGRAB", AMBER)
text(34, 17, "FOR MACOS", GREY)

raw = b''.join(b'\x00' + bytes(v for p in row for v in p) for row in px)
def chunk(t, d):
    return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
open(sys.argv[1], 'wb').write(data)
print("wrote", sys.argv[1], len(data), "bytes")
