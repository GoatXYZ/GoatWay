"""The halo's geometry: the same maths as GoatQuest's Styles/Halo.lua, plus the
angle conventions GoatWay adds (world bearing and screen direction)."""
import math

import gwharness

lua, g = gwharness.load_goatway()
Halo = g.GW_ENV["module:@\\Halo"]
RX, RY = Halo.RX, Halo.RY

assert abs(RX - 280 * (250 - 2.25) / 512) < 1e-9 and abs(RY - 70 * (58 - 2.25) / 128) < 1e-9, "GoatQuest ring metrics"

for i in range(72):
    a = i * 2 * math.pi / 72
    x, y, nx, ny = Halo.EllipsePoint(a, RX, RY)
    assert abs(x * x / (RX * RX) + y * y / (RY * RY) - 1) < 1e-9, "point lies on the ring"
    assert abs(nx * nx + ny * ny - 1) < 1e-9, "unit normal"
    assert nx * x + ny * y > 0, "normal points outward"

x, y, nx, ny = Halo.EllipsePoint(0, RX, RY)
assert abs(x) < 1e-9 and abs(y - RY) < 1e-9 and abs(ny - 1) < 1e-9, "ahead is the far (top) side"
x, y, nx, ny = Halo.EllipsePoint(math.pi / 2, RX, RY)
assert abs(x + RX) < 1e-9 and abs(y) < 1e-9, "counter-clockwise: a quarter turn is the left end"
assert abs(Halo.NormalRotation(0, 1)) < 1e-12, "an up-pointing chevron stays up at the top"


def arc_length(t0, t1, n=2000):
    total = 0.0
    for k in range(n):
        a = t0 + (t1 - t0) * (k + 0.5) / n
        total += math.sqrt((RX * math.cos(a)) ** 2 + (RY * math.sin(a)) ** 2) * abs(t1 - t0) / n
    return total


for t in (0.0, 0.7, math.pi / 2, 2.5):
    t2 = Halo.ArcStep(t, RX, RY, Halo.DOT_STEP)
    assert abs(arc_length(t, t2) - Halo.DOT_STEP) < 0.05, "dots are evenly spaced along the ring"
    assert abs(Halo.ArcStep(t2, RX, RY, -Halo.DOT_STEP) - t) < 1e-3

# Bearings are counter-clockwise from north, like GetPlayerFacing.
assert abs(Halo.RelativeAngle(0, 0)) < 1e-12
assert abs(Halo.RelativeAngle(0, math.pi / 2) - 3 * math.pi / 2) < 1e-12, "north while facing west is to the right"
assert abs(Halo.RelativeAngle(math.pi / 2, 0) - math.pi / 2) < 1e-12, "west while facing north is to the left"

# Screen direction: straight up is ahead, left is a quarter turn counter-clockwise.
assert abs(Halo.ScreenAngle(0, 10)) < 1e-12
assert abs(Halo.ScreenAngle(-10, 0) - math.pi / 2) < 1e-12
assert abs(abs(Halo.ScreenAngle(0, -10)) - math.pi) < 1e-12

print("PASS halo maths: ring, normals, arc steps and angle conventions")
