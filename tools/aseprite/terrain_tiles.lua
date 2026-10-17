-- Pixel-art hex tiles for every biome, built in Aseprite.
--
-- Layout follows the painted Baumgart set (assets/third_party/hex_terrain_basic) so TerrainArt
-- can draw them the same way: the canvas is 1 : 1.73 hex units wide and 3 tall, the pointy-top
-- hex sits in the lower part (top vertex at y 32, centre at y 64, bottom at y 96) and trees or
-- mountains may reach up over the tile behind. Look: limited palettes with ordered dithering,
-- dark outlines, light from the top left (see tools/pixel_style_sample.gd).
--
-- Each tile is saved as an editable .aseprite file (layers "ground" and "decor") plus a PNG.
-- Run:
--   Aseprite.exe -b --script-param out=<folder> --script-param preview=<png> --script tools/aseprite/terrain_tiles.lua

local OUT = app.params.out or "assets/art/terrain"
local PREVIEW = app.params.preview
local VARIANTS = 4

local R = 32 -- hex size (centre to corner) in pixels
local SQ3 = math.sqrt(3)
local W, H = 56, 96
local CX, CY = 28, 64
local UNDER_H = 48 -- underside canvas height (1.5 hex sizes)

-- --- palettes -----------------------------------------------------------------

local function hex(s)
	return { tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16) }
end

local function palette(list)
	local p = {}
	for i, s in ipairs(list) do p[i] = hex(s) end
	return p
end

local DIRT = palette { "2a1f14", "3f2f1d", "574129", "715537", "8c6c46", "a88a5c", "c4a878" }
local TREE = palette { "10200f", "1c3315", "2b4a1c", "3d6224", "527c2c", "6d9536", "94b34e" }
local FLOOR = palette { "17160c", "262312", "38331a", "4b4424" }
local GRASS = palette { "1d2e12", "2b4218", "3c5a1f", "507227", "678a30", "82a23c", "a6bf58" }
local STONE = palette { "1a1c23", "252831", "31343c", "3e4148", "4c4f55", "5c5e62", "6d6e6f", "807f7c", "95938d", "aca8a0", "c6c1b6" }
local SNOW = palette { "a9bdd6", "cddbea", "eaf1f7", "ffffff" }
local SNOW_SHADE = palette { "2e466e", "45628f", "6283b0", "86a6cc" }
local SAND = palette { "7a6a52", "9a8a6e", "b8a98a", "d0c3a6", "e2d8c0", "efe8d6", "faf6ec" }
local LICHEN = palette { "3c4224", "53592c", "6c7236", "878c42", "a1a650", "bcbd66" }
local RUST = hex "a8683a"
local MOSS = palette { "171f0e", "243016", "33421d", "445526", "586a2f", "707f3a", "8c9648" }
local POOL = palette { "0c2b2c", "144140", "1e5a56", "2d766e", "47978a", "77bfae", "b4e2d4" }
local WATER = palette { "0a1a36", "102b54", "173f72", "1f5590", "2c6dab", "4a8bc4", "84b6dd", "d8ecf8" }
local EARTH = palette { "140f0b", "211912", "30241a", "413122", "53402c", "665036" }
local REED = palette { "3b4818", "56662a", "77873a" }
local FLOWER = hex "f0ece0"
-- Swamp: blackish-violet vegetation.
local BOG = palette { "0d0a11", "16101d", "201729", "2b1e37", "372646", "443055", "553c68" }
local BOG_REED = palette { "1a1222", "3a2850", "5e4680" }
local BOG_CATTAIL = hex "2a1416"
local BOG_FLOWER = hex "a98cc8"

local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

-- Palette colour for a value 0..1, dithered between neighbouring entries.
local function dither(pal, v, x, y)
	local n = #pal
	local s = clamp(v, 0, 0.9999) * (n - 1)
	local i = math.floor(s)
	local t = (BAYER[(y % 4) * 4 + (x % 4) + 1] + 0.5) / 16
	if s - i > t then i = math.min(i + 1, n - 1) end
	return pal[i + 1]
end

local function mix(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- --- noise --------------------------------------------------------------------

local function hash(x, y, s)
	local n = math.floor(x) * 374761393 + math.floor(y) * 668265263 + s * 1442695041
	n = (n ~ (n >> 13)) * 1274126177
	n = n ~ (n >> 16)
	return (n & 0xffffff) / 0xffffff
end

local function vnoise(x, y, s)
	local x0, y0 = math.floor(x), math.floor(y)
	local fx, fy = x - x0, y - y0
	fx = fx * fx * (3 - 2 * fx)
	fy = fy * fy * (3 - 2 * fy)
	local a, b = hash(x0, y0, s), hash(x0 + 1, y0, s)
	local c, d = hash(x0, y0 + 1, s), hash(x0 + 1, y0 + 1, s)
	return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
end

local function fbm(x, y, s)
	local sum, amp, total = 0, 1, 0
	for o = 0, 3 do
		sum = sum + vnoise(x, y, s + o * 31) * amp
		total = total + amp
		amp = amp * 0.5
		x, y = x * 2.03, y * 2.03
	end
	return sum / total
end

-- Nearest and second-nearest jittered cell centre (moss mounds, stone slabs).
local function cells(x, y, size, s)
	local d1, d2, ox, oy, cellx, celly = 99, 99, 0, 0, 0, 0
	local cx, cy = math.floor(x / size), math.floor(y / size)
	for gy = cy - 1, cy + 1 do
		for gx = cx - 1, cx + 1 do
			local px = gx * size + hash(gx, gy, s) * size
			local py = gy * size + hash(gx, gy, s + 1) * size
			local dd = math.sqrt((x - px) ^ 2 + ((y - py) * 1.3) ^ 2)
			if dd < d1 then
				d2, d1, ox, oy, cellx, celly = d1, dd, (x - px) / size, (y - py) / size, gx, gy
			elseif dd < d2 then
				d2 = dd
			end
		end
	end
	return d1, d2, ox, oy, cellx, celly
end

-- --- pixel buffers ------------------------------------------------------------

local function buffer(w, h) return { w = w, h = h, px = {} } end

local function get(b, x, y)
	if x < 0 or y < 0 or x >= b.w or y >= b.h then return nil end
	return b.px[y * b.w + x]
end

local function put(b, x, y, c)
	x, y = math.floor(x), math.floor(y)
	if x < 0 or y < 0 or x >= b.w or y >= b.h then return end
	b.px[y * b.w + x] = c
end

-- Darken what is already there (ground shadows).
local function shade(b, x, y, f)
	local c = get(b, math.floor(x), math.floor(y))
	if c then put(b, x, y, { c[1] * f, c[2] * f * 1.02, c[3] * f * 1.1 }) end
end

-- Pixel centre relative to the hex centre.
local function rel(x, y) return x + 0.5 - CX, y + 0.5 - CY end

local function in_hex(x, y, inset)
	local px, py = rel(x, y)
	local r = R - (inset or 0)
	return math.abs(px) <= SQ3 / 2 * r and math.abs(py) <= r - math.abs(px) / SQ3
end

-- Bottom edge of the hex at column x.
local function hex_bottom(x)
	local px = x + 0.5 - CX
	return CY + R - math.abs(px) / SQ3
end

local function fill_hex(b, fn)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if in_hex(x, y) then
				local px, py = rel(x, y)
				put(b, x, y, fn(x, y, px, py))
			end
		end
	end
end

-- Dark rim on the hex edge, with a lit bevel just inside the top-left edges. `lower_only` keeps
-- the upper edges open (a mountain continues above them).
local function hex_rim(b, dark, lower_only)
	local edge, lit = {}, {}
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local c = get(b, x, y)
			if c and in_hex(x, y) then
				local _, py = rel(x, y)
				local open = not in_hex(x - 1, y) or not in_hex(x + 1, y) or not in_hex(x, y - 1) or not in_hex(x, y + 1)
				if open and (not lower_only or py > 0) then
					edge[#edge + 1] = { x, y, mix(c, dark, 0.75) }
				elseif not lower_only and py < 0 and (not in_hex(x - 2, y) or not in_hex(x, y - 2)) and (rel(x, y)) < 6 then
					lit[#lit + 1] = { x, y, mix(c, { 255, 250, 230 }, 0.18) }
				end
			end
		end
	end
	for _, e in ipairs(edge) do put(b, e[1], e[2], e[3]) end
	for _, e in ipairs(lit) do put(b, e[1], e[2], e[3]) end
end

-- Light falling from the top left: positive on the upper left of the hex.
local function light(px, py) return -(px + py) / (2 * R) * 0.16 end

-- Points scattered over the hex (stable for a seed), at least `inset` pixels from the rim.
local function scatter(count, s, inset)
	local list = {}
	local i = 0
	while #list < count and i < count * 20 do
		i = i + 1
		local x = math.floor(hash(i, 1, s) * W)
		local y = math.floor(hash(i, 2, s) * H)
		if in_hex(x, y, inset) then list[#list + 1] = { x, y, hash(i, 3, s) } end
	end
	return list
end

-- --- small decor ------------------------------------------------------------------

local function pebble(b, x, y, pal)
	put(b, x, y, pal[#pal])
	put(b, x + 1, y, pal[#pal - 2])
	put(b, x, y + 1, pal[#pal - 3])
	put(b, x + 1, y + 1, pal[2])
end

local function tuft(b, x, y, pal)
	put(b, x, y, pal[2])
	put(b, x - 1, y - 1, pal[#pal - 1])
	put(b, x + 1, y - 1, pal[#pal - 2])
	put(b, x, y - 1, pal[#pal])
end

local function shadow_ellipse(g, cx, cy, rx, ry, f)
	for yy = -math.ceil(ry), math.ceil(ry) do
		for xx = -math.ceil(rx), math.ceil(rx) do
			local ex, ey = xx / rx, yy / ry
			if ex * ex + ey * ey <= 1 then shade(g, cx + xx, cy + yy, f) end
		end
	end
end

-- A round tree crown seen from above at an angle: stands `lift` pixels above its foot,
-- casts a shadow down to the right, lumpy edge, lit top left, outlined bottom right.
local function crown(g, d, tx, ty, r, s)
	shadow_ellipse(g, tx + 2, ty + 1, r * 1.15, r * 0.7, 0.5)
	local cy = ty - math.floor(r * 0.9)
	local n = math.ceil(r) + 1
	for yy = -n, n do
		for xx = -n, n do
			local x, y = tx + xx, cy + yy
			local dist = math.sqrt(xx * xx + yy * yy) / (r * (0.86 + 0.28 * vnoise(x * 0.9, y * 0.9, s)))
			if dist <= 1 then
				local nx, ny = xx / r, yy / r
				local c
				if dist > 0.84 then
					c = (nx + ny > -0.35) and TREE[1] or TREE[3]
				else
					local v = 0.5 - (nx + ny) * 0.32 + (1 - dist) * 0.12 + (vnoise(x * 0.8, y * 0.8, s + 7) - 0.5) * 0.4
					c = dither(TREE, v, x, y)
				end
				put(d, x, y, c)
			end
		end
	end
end

-- A grey boulder: an irregular polygon with a flat lit top and one shaded facet per side,
-- so it reads as broken rock rather than a ball.
local function boulder(g, d, bx, by, r, s)
	shadow_ellipse(g, bx + 1.5, by + 1, r * 1.2, r * 0.6, 0.6)
	local cy = by - math.floor(r * 0.45)
	local n = 5 + math.floor(hash(bx, by, s) * 3)
	local a0 = hash(by, bx, s) * math.pi
	local verts = {}
	for k = 0, n - 1 do
		local a = a0 + k * 2 * math.pi / n + (hash(k, 1, s) - 0.5) * 0.6
		local rr = r * (0.75 + hash(k, 2, s) * 0.4)
		verts[k + 1] = { math.cos(a) * rr, math.sin(a) * rr * 0.8 }
	end
	-- Outward normal and distance to the line of every side.
	local edges = {}
	for k = 1, n do
		local a, b = verts[k], verts[k % n + 1]
		local nx, ny = b[2] - a[2], a[1] - b[1]
		local len = math.sqrt(nx * nx + ny * ny)
		nx, ny = nx / len, ny / len
		if nx * a[1] + ny * a[2] < 0 then nx, ny = -nx, -ny end
		edges[k] = { nx, ny, nx * a[1] + ny * a[2] }
	end
	local m = math.ceil(r * 1.2) + 1
	for yy = -m, m do
		for xx = -m, m do
			local nearest, side = 99, nil
			for k, e in ipairs(edges) do
				local dist = e[3] - (e[1] * xx + e[2] * yy)
				if dist < nearest then nearest, side = dist, k end
			end
			if nearest >= 0 then
				local e = edges[side]
				local facing = e[1] + e[2] -- > 0: faces down/right, away from the light
				local x, y = bx + xx, cy + yy
				local c
				if nearest < 0.9 then
					c = facing > 0.2 and STONE[2] or STONE[4]
				elseif nearest > r * 0.42 then
					c = dither(STONE, 0.9 + hash(1, side, s) * 0.08 - (xx + yy) / r * 0.06, x, y)
				else
					c = dither(STONE, 0.6 - facing * 0.3 + (hash(side, 3, s) - 0.5) * 0.12 + nearest / r * 0.1, x, y)
				end
				put(d, x, y, c)
			end
		end
	end
end

-- Flat grey slabs with dark cracks where the scree noise is above `threshold`; the patch edge
-- frays into the grass through the dither pattern.
local function scree(g, s, threshold)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local n = fbm(x * 0.13, y * 0.17, s + 11)
			if in_hex(x, y) and n > threshold + BAYER[(y % 4) * 4 + (x % 4) + 1] / 16 * 0.04 then
				local px, py = rel(x, y)
				local d1, d2, ox, oy, cx, cy = cells(x, y, 5, s + 12)
				local v
				if d2 - d1 < 0.9 then
					v = 0.34 + light(px, py)
				else
					v = 0.62 + (hash(cx, cy, s) - 0.5) * 0.3 + (n - threshold) * 0.6 - (ox + oy) * 0.25 + light(px, py)
				end
				put(g, x, y, dither(STONE, v, x, y))
			end
		end
	end
end

local function reeds(d, x, y, s)
	for i = 0, 2 do
		local sx = x + i * 2 - 2
		local h = 3 + math.floor(hash(sx, y, s) * 3)
		local lean = (i - 1) * 0.25
		for k = 0, h - 1 do
			put(d, sx + math.floor(k * lean + 0.5), y - k, k == h - 1 and hash(sx, y, s + 1) > 0.4 and BOG_CATTAIL or BOG_REED[(k % 2) + 2])
		end
		put(d, sx, y, BOG_REED[1])
	end
end

-- --- biomes ---------------------------------------------------------------------
-- Each returns (ground, decor) buffers of W x H.

local function dirt(s, g, d)
	fill_hex(g, function(x, y, px, py)
		local wash = fbm(x * 0.09 + s, y * 0.16, s)
		local v = 0.5 + (wash - 0.5) * 0.9 + light(px, py) + (vnoise(x * 0.6, y * 0.6, s + 5) - 0.5) * 0.15
		return dither(DIRT, v, x, y)
	end)
	for _, p in ipairs(scatter(9, s + 1, 3)) do pebble(g, p[1], p[2], DIRT) end
	for _, p in ipairs(scatter(5, s + 2, 4)) do tuft(d, p[1], p[2], GRASS) end
	hex_rim(g, EARTH[1])
end

local function forest(s, g, d)
	fill_hex(g, function(x, y, px, py)
		return dither(FLOOR, 0.45 + (fbm(x * 0.2, y * 0.2, s) - 0.5) * 0.9 + light(px, py), x, y)
	end)
	for _, p in ipairs(scatter(6, s + 3, 3)) do tuft(g, p[1], p[2], GRASS) end
	hex_rim(g, EARTH[1])
	-- Crowns on a jittered grid, back rows first so the front ones overlap them.
	local trees = {}
	local cell = 8
	for gy = -1, H // cell + 1 do
		for gx = -1, W // cell + 1 do
			local tx = gx * cell + math.floor(hash(gx, gy, s) * cell) + (gy % 2) * 4
			local ty = gy * cell * 0.75 + math.floor(hash(gx, gy, s + 1) * cell * 0.6)
			ty = math.floor(ty)
			if in_hex(tx, ty, 3) and hash(gx, gy, s + 2) > 0.08 then
				trees[#trees + 1] = { tx, ty, 3.4 + hash(gx, gy, s + 3) * 1.6 }
			end
		end
	end
	table.sort(trees, function(a, b) return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1]) end)
	for i, t in ipairs(trees) do crown(g, d, t[1], t[2], t[3], s + i) end
end

-- Light grey rock ground with some colour in it: lighter grey patches, yellow-green lichen,
-- small gravel (light pebbles with a dark pixel below right) and a few rusty stones.
local function rock_ground(s, g)
	fill_hex(g, function(x, y, px, py)
		local v = 0.5 + (fbm(x * 0.12, y * 0.15, s + 2) - 0.5) * 0.2 + light(px, py) + (vnoise(x * 0.7, y * 0.7, s + 6) - 0.5) * 0.05
		if fbm(x * 0.2, y * 0.24, s + 30) > 0.72 then
			return dither(LICHEN, v + 0.05, x, y)
		end
		-- Lighter grey patches instead of one flat tone.
		return dither(STONE, v + (fbm(x * 0.07, y * 0.09, s + 31) > 0.55 and 0.08 or 0), x, y)
	end)
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if in_hex(x, y, 1.5) and in_hex(x + 1, y + 1, 1.5) then
				local h = hash(x, y, s + 21)
				if h > 0.975 then
					put(g, x, y, STONE[9 + math.floor(hash(x, y, s + 22) * 3)])
					put(g, x + 1, y + 1, STONE[4])
				elseif h < 0.03 then
					put(g, x, y, STONE[5])
				elseif h < 0.033 then
					put(g, x, y, RUST)
				end
			end
		end
	end
	for _, q in ipairs(scatter(6, s + 23, 3)) do pebble(g, q[1], q[2], STONE) end
end

local function grassland(s, g, d, p)
	fill_hex(g, function(x, y, px, py)
		local v = 0.48 + (fbm(x * 0.11, y * 0.14, s) - 0.5) * 0.8 + light(px, py)
		return dither(p, v, x, y)
	end)
	for _, q in ipairs(scatter(14, s + 4, 2)) do tuft(g, q[1], q[2], p) end
	for _, q in ipairs(scatter(7, s + 5, 3)) do put(g, q[1], q[2], FLOWER) end
end

local function highlands(s, g, d)
	rock_ground(s, g)
	scree(g, s, 0.66)
	hex_rim(g, STONE[2])
	-- Clusters of boulders.
	local rocks = {}
	for ci, c in ipairs(scatter(4, s + 6, 8)) do
		for k = 1, 3 + math.floor(c[3] * 3) do
			local bx = c[1] + math.floor((hash(ci, k, s + 7) - 0.5) * 12)
			local by = c[2] + math.floor((hash(ci, k, s + 8) - 0.5) * 7)
			if in_hex(bx, by, 3) then rocks[#rocks + 1] = { bx, by, 2.4 + hash(ci, k, s + 9) * 2.4 } end
		end
	end
	table.sort(rocks, function(a, b) return a[2] < b[2] end)
	for i, r in ipairs(rocks) do boulder(g, d, r[1], r[2], r[3], s + i * 3) end
end

-- One pointed rocky peak with its foot at (px, foot) and its tip `height` pixels above it:
-- lit left flank, shaded right flank, gullies, a snow cap on the taller ones.
local function peak(g, d, px, foot, height, s)
	local tip = foot - height
	local slope = 1.15 + hash(px, foot, s) * 0.3
	local half = height / slope
	local function inside(x, y)
		local dx = math.abs(x + 0.5 - px)
		if dx > half or y < tip + dx * slope + (vnoise(x * 0.5, y * 0.3, s) - 0.5) * 2.5 then return false end
		if y > foot - (dx / half) ^ 2 * 3 then return false end
		return y + 0.5 <= hex_bottom(x) and math.abs(x + 0.5 - CX) <= SQ3 / 2 * R
	end
	shadow_ellipse(g, px + half * 0.6, foot - 1, half * 0.8, 3, 0.55)
	local cap = height >= 17 and 2 + height * 0.12 or 0
	for y = math.max(0, math.floor(tip)), math.ceil(foot) do
		for x = math.floor(px - half) - 1, math.ceil(px + half) + 1 do
			if inside(x, y) then
				local ridge = px + (vnoise(y * 0.25, 9, s) - 0.5) * 3 * (y - tip) / height
				local lit = x + 0.5 < ridge
				local gully = vnoise(x * 0.45 + (y - tip) * 0.35 * (lit and 1 or -1), y * 0.12, s + 3)
				local across = math.abs(x + 0.5 - ridge) / half
				local v = (lit and 0.86 - across * 0.18 or 0.48 - across * 0.1) + (gully - 0.5) * 0.4 + (y - tip) / height * 0.06
				-- Broken rock faces: each small cell its own brightness, darker cracks between.
				local d1, d2, _, _, cx, cy = cells(x, y * 1.3, 4, s + 8)
				v = v + (hash(cx, cy, s) - 0.5) * 0.16 - (d2 - d1 < 0.7 and 0.12 or 0)
				local c
				if y < tip + cap + (gully - 0.5) * 4 then
					c = lit and dither(SNOW, 0.5 + v * 0.5, x, y) or dither(SNOW_SHADE, v * 1.7, x, y)
				else
					c = dither(STONE, v, x, y)
				end
				if not inside(x, y - 1) or not inside(x - 1, y) or not inside(x + 1, y) then
					c = lit and STONE[6] or STONE[3]
				end
				put(d, x, y, c)
			end
		end
	end
end

-- Mountain from Tier 4: a low pointed peak with two small hills on rocky grass. Back peaks are
-- drawn first so the front ones overlap them.
local function mountain(s, g, d)
	rock_ground(s, g)
	scree(g, s, 0.66)
	hex_rim(g, STONE[2])
	local function j(i, k, range) return math.floor((hash(i, k, s) - 0.5) * range) end
	-- { x, foot, height }: one peak in the middle that stays inside the hex (tip around y 38,
	-- below the top vertex at y 32) and two small bare hills left and right. Kept low so the
	-- towers standing on the tile stay readable.
	local peaks = {
		{ CX + j(1, 1, 4), 58 + j(1, 2, 3), 19 + j(1, 3, 4) },
		{ 12 + j(2, 1, 4), 70 + j(2, 2, 4), 11 + j(2, 3, 3) },
		{ 44 + j(3, 1, 4), 72 + j(3, 2, 4), 11 + j(3, 3, 3) },
	}
	table.sort(peaks, function(a, b) return a[2] < b[2] end)
	for i, p in ipairs(peaks) do peak(g, d, p[1], p[2], p[3], s + i * 5) end
	hex_rim(d, STONE[2], true)
end

local function dunes(s, g, d)
	fill_hex(g, function(x, y, px, py)
		local u = y + math.sin(x * 0.16 + s) * 5 + (fbm(x * 0.07, y * 0.07, s) - 0.5) * 16
		local f = (u % 11) / 11
		-- Dark lee slope right below each crest, lit slope rising up to the next crest.
		local v = f < 0.32 and (0.28 + f * 0.6) or (0.5 + (f - 0.32) * 0.55)
		v = v + math.sin(u * 2.4) * 0.04 + light(px, py)
		return dither(SAND, v, x, y)
	end)
	for _, p in ipairs(scatter(4, s + 1, 4)) do pebble(g, p[1], p[2], SAND) end
	for _, p in ipairs(scatter(3, s + 2, 5)) do tuft(d, p[1], p[2], REED) end
	hex_rim(g, SAND[1])
end

local function swamp(s, g, d)
	local wet = {}
	fill_hex(g, function(x, y, px, py)
		local pool = fbm(x * 0.08, y * 0.1, s + 9)
		if pool < 0.4 and in_hex(x, y, 3) then
			wet[y * W + x] = true
			local depth = (0.4 - pool) * 8
			local glint = vnoise(x * 0.5, y * 1.4, s + 2) > 0.8
			return glint and POOL[4] or dither(POOL, 0.45 - depth + light(px, py), x, y)
		end
		local d1, d2, ox, oy = cells(x, y, 9, s)
		if d2 - d1 < 0.8 then return BOG[2] end
		local v = 0.5 - (ox + oy) * 0.45 + (vnoise(x * 0.7, y * 0.7, s + 3) - 0.5) * 0.3 + light(px, py)
		return dither(BOG, v, x, y)
	end)
	-- Pool banks: dark on the upper rim (in shadow), lit on the lower one.
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local i = y * W + x
			if wet[i] and not wet[i - W] and get(g, x, y - 1) then put(g, x, y, POOL[1]) end
			if wet[i] and not wet[i + W] then put(g, x, y, POOL[3]) end
		end
	end
	for _, p in ipairs(scatter(7, s + 4, 3)) do
		if not wet[p[2] * W + p[1]] then put(g, p[1], p[2], BOG_FLOWER) end
	end
	local spots = scatter(8, s + 5, 4)
	table.sort(spots, function(a, b) return a[2] < b[2] end)
	for i, p in ipairs(spots) do
		if not wet[p[2] * W + p[1]] then reeds(d, p[1], p[2], s + i) end
	end
	hex_rim(g, BOG[1])
end

local function lake(s, g, d)
	fill_hex(g, function(x, y, px, py)
		local edge = R - math.max(math.abs(px) * 2 / SQ3, math.abs(py) + math.abs(px) / SQ3)
		local v = 0.42 + (fbm(x * 0.1, y * 0.12, s) - 0.5) * 0.6 + light(px, py)
		if edge < 3 then v = v + (3 - edge) * 0.08 end
		local wave = vnoise(x * 0.22 + y * 0.05, y * 0.75, s + 6)
		if wave > 0.86 then return WATER[8] end
		if wave > 0.8 then return WATER[7] end
		return dither(WATER, v, x, y)
	end)
	hex_rim(g, WATER[1])
end

-- Rocky underside below an edge tile: a band hanging from the hex's two lower sides.
local function underside(s)
	local b = buffer(W, UNDER_H)
	local function top(x) return 16 * (1 - math.abs(x + 0.5 - CX) / (SQ3 / 2 * R)) end
	local function bottom(x) return top(x) + 24 + vnoise(x * 0.4, 2, s) * 8 end
	for y = 0, UNDER_H - 1 do
		for x = 0, W - 1 do
			local t, bt = top(x), bottom(x)
			if y >= t - 1 and y <= bt then
				local depth = y - t
				local left = x + 0.5 < CX
				local strata = vnoise(x * 0.12, depth * 0.5, s)
				local v = (left and 0.62 or 0.36) + (strata - 0.5) * 0.4 - depth * 0.012
				local c = dither(EARTH, v, x, y)
				if bt - y < 1 or math.abs(x + 0.5 - CX) < 0.6 and depth > 2 then c = EARTH[1] end
				if hash(x, y, s + 4) > 0.97 and depth > 4 then c = STONE[4] end
				put(b, x, y, c)
			end
		end
	end
	-- Roots hanging off the lower edge.
	for i = 1, 5 do
		local x = math.floor(hash(i, 1, s) * (W - 8)) + 4
		local y0 = math.floor(bottom(x))
		for k = 1, 2 + math.floor(hash(i, 2, s) * 4) do put(b, x, y0 + k, EARTH[2]) end
	end
	return b
end

-- --- the HQ: a grey castle with orange roofs ---------------------------------------

local DARK_STONE = palette { "2c2c31", "38383e", "45454c", "53535b", "62626a", "72727a", "83838b", "95959c", "a8a8ae", "bcbcc1", "d1d1d4" }
local ROOF = palette { "4a1e0e", "6e2e12", "94421a", "b85a22", "d8762e", "f09a48" }
local ASH = palette { "3a2a1e", "4c3727", "604630", "74563a", "8a6846", "a07c55" }
local BANNER = palette { "6a2a0c", "a4441a", "d86a26", "f59440" }
local GLOW = palette { "5e4410", "b88a1c", "ffd23c", "fff4b0" }

-- The HQ takes the island's dominant biome; its castle shows it in the ground around the
-- walls, the roof tiles and the banners (in the biome's colour, as in Biome.COLORS), Lake adds
-- a moat. Neutral is the plain look (hexCastle00); the others are hexCastle<Biome>00.
local CASTLE_THEMES = {
	{ "hexCastle00", { ground = ASH, roof = ROOF, banner = BANNER } },
	{ "hexCastleForest00", {
		ground = palette { "1d2e12", "2b4218", "3c5a1f", "507227", "678a30", "82a23c" },
		roof = palette { "14260e", "1f3a14", "2d521b", "3f6c24", "56882e", "74a63c" },
		banner = palette { "143a1a", "22602a", "3f9a4a", "74c47a" },
		tufts = TREE,
	} },
	{ "hexCastleMountain00", {
		ground = palette { "252831", "31343c", "3e4148", "4c4f55", "5c5e62", "6d6e6f" },
		roof = palette { "1c2230", "2a3346", "3b4760", "4f5e7c", "687a98", "8a9cb6" },
		banner = palette { "4a1612", "7a2620", "b8433a", "e07a6a" },
	} },
	{ "hexCastlePlains00", {
		ground = palette { "7a6a52", "9a8a6e", "b8a98a", "d0c3a6", "e2d8c0", "efe8d6" },
		roof = palette { "6a5a3a", "8c7a50", "b09a68", "cbb884", "e2d2a2", "f4e8c4" },
		banner = palette { "8a8a82", "b8b8b0", "e2e2da", "f2f2ec" },
	} },
	{ "hexCastleSwamp00", {
		ground = palette { "0d0a11", "16101d", "201729", "2b1e37", "372646", "443055" },
		roof = palette { "1a1222", "2a1d38", "3c2a52", "50386c", "664a88", "8062a6" },
		banner = palette { "2a1840", "4a2a70", "7b4bb0", "a98cc8" },
		tufts = BOG_REED,
	} },
	{ "hexCastleLake00", {
		ground = palette { "1d2e12", "2b4218", "3c5a1f", "507227", "678a30", "82a23c" },
		roof = palette { "0a1a36", "102b54", "173f72", "1f5590", "2c6dab", "4a8bc4" },
		banner = palette { "0e2a54", "1a4a8a", "2f6db5", "6aa0dc" },
		moat = WATER,
	} },
}

-- A small height model: every ground pixel may carry a column, stone up to `wall` and roof
-- above that up to `h`. Columns are drawn back to front, so nearer ones cover farther ones;
-- `nx` is the horizontal normal (-1 faces left into the light, +1 faces right into shadow).
local function castle(s, g, d, theme)
	-- The theme's palettes stand in for the plain look's below.
	theme = theme or CASTLE_THEMES[1][2]
	local ASH, ROOF, BANNER = theme.ground, theme.roof, theme.banner
	local cols = {}
	local function set(x, y, h, wall, nx)
		if x < 0 or x >= W or y < 0 or y >= H then return end
		local c = cols[y * W + x]
		if not c or h > c.h then cols[y * W + x] = { h = h, wall = wall, nx = nx } end
	end
	local function height_at(x, y)
		local c = cols[y * W + x]
		return c and c.h or 0
	end
	-- Crenellations: every other pixel of a battlement rim stands 2 higher.
	local function merlon(x, y) return (x + y) % 2 == 0 and 2 or 0 end

	local function ring_wall(cx, cy, rx, ry, height, thick)
		for y = cy - ry - 1, cy + ry + 1 do
			for x = cx - rx - 1, cx + rx + 1 do
				local dx, dy = x + 0.5 - cx, y + 0.5 - cy
				local e = math.sqrt((dx / rx) ^ 2 + (dy / ry) ^ 2)
				if e <= 1 and e > 1 - thick / ry then
					local h = height + (e > 1 - 1 / ry and merlon(x, y) or 0)
					set(x, y, h, h, dx / rx)
				end
			end
		end
	end
	-- Round tower; `roof` > 0 adds a pointed tiled cone, otherwise it gets battlements.
	local function tower(cx, cy, r, height, roof)
		for y = math.floor(cy - r - 1), math.ceil(cy + r + 1) do
			for x = math.floor(cx - r - 1), math.ceil(cx + r + 1) do
				local dx, dy = x + 0.5 - cx, (y + 0.5 - cy) * 1.25
				local dist = math.sqrt(dx * dx + dy * dy)
				if dist <= r then
					if roof > 0 then
						set(x, y, height + roof * (1 - dist / r), height, dx / r)
					else
						local h = height + (dist > r - 1 and merlon(x, y) or 0)
						set(x, y, h, h, dx / r)
					end
				end
			end
		end
	end
	local function block(x0, y0, x1, y1, height)
		for y = y0, y1 do
			for x = x0, x1 do
				local rim = x == x0 or x == x1 or y == y0 or y == y1
				local h = height + (rim and merlon(x, y) or 0)
				set(x, y, h, h, (x - (x0 + x1) / 2) / (x1 - x0) * 1.6)
			end
		end
	end

	-- Layout (ground coordinates; hex centre 28,64).
	local CX0, CY0, RX, RY = 28, 67, 20, 13
	local WALL = 4
	-- Keep in the middle of the courtyard: a battlemented block, a tall main spire rising from
	-- its centre and two slimmer spires on its back corners. All roofs are steep and pointed.
	local KX0, KY0, KX1, KY1, KH = 21, 59, 35, 66, 10
	local MAIN = { 28, 60, 3.6, 16, 13 }
	local SPIRE_A = { 21.5, 59, 2.6, 13, 9 }
	local SPIRE_B = { 34.5, 59, 2.6, 13, 9 }
	local SIDE = { 3.2, 8, 8 }
	ring_wall(CX0, CY0, RX, RY, WALL, 2)
	block(KX0, KY0, KX1, KY1, KH)
	tower(table.unpack(SPIRE_A))
	tower(table.unpack(SPIRE_B))
	tower(table.unpack(MAIN))
	tower(CX0 - RX + 1, CY0, SIDE[1], SIDE[2], SIDE[3])
	tower(CX0 + RX - 1, CY0, SIDE[1], SIDE[2], SIDE[3])
	tower(CX0 - 4, CY0 + RY, 2.4, 7, 6)
	tower(CX0 + 4, CY0 + RY, 2.4, 7, 6)

	-- Ground: scorched dirt, dark flagstones in the courtyard, a trodden path from the gate.
	fill_hex(g, function(x, y, px, py)
		local dx, dy = x + 0.5 - CX0, y + 0.5 - CY0
		local inner = (dx / RX) ^ 2 + (dy / RY) ^ 2 < 0.8
		if inner then
			local d1, d2 = cells(x, y * 1.4, 4, s + 3)
			return d2 - d1 < 0.8 and DARK_STONE[6] or dither(DARK_STONE, 0.66 + (vnoise(x * 0.6, y * 0.6, s) - 0.5) * 0.25, x, y)
		end
		local v = 0.42 + (fbm(x * 0.1, y * 0.14, s) - 0.5) * 0.7 + light(px, py)
		local path = math.abs(dx + math.sin(y * 0.4) * 0.8) < 2.2 and dy > RY
		if path then v = v + 0.25 end
		-- Lake: a moat just outside the walls, bridged by the path to the gate.
		local e = math.sqrt((dx / RX) ^ 2 + (dy / RY) ^ 2)
		if theme.moat and e > 1.02 and e < 1.3 and not path then
			return dither(theme.moat, 0.45 + (vnoise(x * 0.5, y * 0.5, s) - 0.5) * 0.4 + light(px, py), x, y)
		end
		return dither(ASH, v, x, y)
	end)
	if theme.tufts then
		for _, p in ipairs(scatter(14, s + 5, 3)) do
			local dx, dy = p[1] + 0.5 - CX0, p[2] + 0.5 - CY0
			if (dx / RX) ^ 2 + (dy / RY) ^ 2 > 1.35 then tuft(g, p[1], p[2], theme.tufts) end
		end
	end
	for _, p in ipairs(scatter(6, s + 1, 3)) do
		local dx, dy = p[1] + 0.5 - CX0, p[2] + 0.5 - CY0
		if (dx / RX) ^ 2 + (dy / RY) ^ 2 > 1.3 then pebble(g, p[1], p[2], ASH) end
	end
	hex_rim(g, ASH[1])
	-- Shadows cast down and to the right.
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			if get(g, x, y) then
				for t = 1, 14 do
					local sx, sy = x - t, math.floor(y - t * 0.5)
					if sx >= 0 and sy >= 0 and height_at(sx, sy) > t * 0.9 then
						shade(g, x, y, 0.68)
						break
					end
				end
			end
		end
	end

	-- Columns, back to front.
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local c = cols[y * W + x]
			if c then
				local top = math.floor(c.h + 0.5)
				local slope = (height_at(x + 1, y) - height_at(x - 1, y)) + (height_at(x, y + 1) - height_at(x, y - 1))
				for k = 0, top do
					local sy = y - k
					local col
					if k > c.wall then
						-- Roof tiles: lit where they face up-left.
						col = dither(ROOF, 0.6 - c.nx * 0.4 - slope * 0.06, x, sy)
					elseif k == top then
						col = dither(DARK_STONE, 0.82 - c.nx * 0.1, x, sy)
					else
						-- Wall face: lit on the left, darker towards the ground, sparse mortar seams.
						local v = 0.36 - c.nx * 0.26 + k / math.max(c.wall, 1) * 0.1
						if sy % 4 == 0 or (x + (sy // 4) % 2 * 3) % 6 == 0 then v = v - 0.07 end
						col = dither(DARK_STONE, v, x, sy)
						if k <= 1 and hash(x, sy, s + 40) > 0.55 then col = MOSS[4 + k] end
					end
					put(d, x, sy, col)
				end
			end
		end
	end

	-- Gate: a dark arch in the front wall with firelight from the courtyard.
	local gy = CY0 + RY
	for k = 0, WALL - 1 do
		for x = CX0 - 2, CX0 + 1 do
			if not (k == WALL - 1 and (x == CX0 - 2 or x == CX0 + 1)) then
				put(d, x, gy - k, k == 0 and GLOW[1] or DARK_STONE[1])
			end
		end
	end
	-- Torches beside the gate, with a warm glow on the ground.
	for _, tx in ipairs({ CX0 - 4, CX0 + 3 }) do
		put(d, tx, gy - 3, GLOW[4])
		put(d, tx, gy - 2, GLOW[3])
		put(d, tx, gy - 1, DARK_STONE[1])
		for yy = 1, 3 do
			for xx = -2, 2 do
				local c = get(g, tx + xx, gy + yy)
				if c and xx * xx + yy * yy < 6 then put(g, tx + xx, gy + yy, mix(c, GLOW[2], 0.3)) end
			end
		end
	end
	-- Glowing window slits.
	local function window(x, y)
		put(d, x, y, GLOW[3])
		put(d, x, y + 1, GLOW[2])
	end
	-- Front ground row of a round tower (its depth is squashed by 1.25).
	local function front(t) return math.floor(t[2] + t[3] / 1.25) end
	window(MAIN[1], front(MAIN) - MAIN[4] + 3)
	window(MAIN[1], front(MAIN) - MAIN[4] + 8)
	window(math.floor(SPIRE_A[1]), front(SPIRE_A) - SPIRE_A[4] + 3)
	window(math.floor(SPIRE_B[1]), front(SPIRE_B) - SPIRE_B[4] + 3)
	window(23, KY1 - KH + 4)
	window(28, KY1 - KH + 5)
	window(33, KY1 - KH + 4)
	window(CX0 - RX + 1, CY0 + 2 - SIDE[2] + 3)
	window(CX0 + RX - 2, CY0 + 2 - SIDE[2] + 3)
	-- Red banners hanging from the keep, flags on the spires.
	for _, bx in ipairs({ 25, 30 }) do
		for k = 0, 4 do
			put(d, bx, KY1 - KH + 2 + k, BANNER[(k < 4) and 3 or 1])
			put(d, bx + 1, KY1 - KH + 2 + k, BANNER[(k < 4) and 2 or 1])
		end
	end
	local function flag(t)
		local x, tip = math.floor(t[1]), math.floor(t[2] - t[4] - t[5])
		for k = 1, 3 do put(d, x, tip - k, DARK_STONE[1]) end
		put(d, x + 1, tip - 3, BANNER[4])
		put(d, x + 2, tip - 3, BANNER[3])
		put(d, x + 1, tip - 2, BANNER[2])
		put(d, x + 3, tip - 2, BANNER[2])
	end
	flag(MAIN)
	flag(SPIRE_A)
	flag(SPIRE_B)

	-- Soft dark outline on the lower and right edges of the silhouette.
	local edge = {}
	for i, c in pairs(d.px) do
		local x, y = i % W, i // W
		if not get(d, x + 1, y) or not get(d, x, y + 1) and not cols[(y + 1) * W + x] then
			edge[#edge + 1] = { x, y, mix(c, DARK_STONE[1], 0.5) }
		end
	end
	for _, e in ipairs(edge) do put(d, e[1], e[2], e[3]) end
end

-- --- saving ------------------------------------------------------------------------

local function to_image(b)
	local img = Image(b.w, b.h, ColorMode.RGB)
	img:clear(0)
	for i, c in pairs(b.px) do
		img:drawPixel(i % b.w, i // b.w, app.pixelColor.rgba(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5), 255))
	end
	return img
end

local function save(name, layers)
	local spr = Sprite(layers[1][2].w, layers[1][2].h, ColorMode.RGB)
	for i, entry in ipairs(layers) do
		local layer = i == 1 and spr.layers[1] or spr:newLayer()
		layer.name = entry[1]
		spr:newCel(layer, 1, to_image(entry[2]), Point(0, 0))
	end
	spr:saveAs(OUT .. "/src/" .. name .. ".aseprite")
	spr:saveCopyAs(OUT .. "/" .. name .. ".png")
	spr:close()
end

local function flatten(layers)
	local out = buffer(layers[1].w, layers[1].h)
	for _, b in ipairs(layers) do
		for i, c in pairs(b.px) do out.px[i] = c end
	end
	return out
end

local BIOMES = {
	{ "hexDirt", dirt },
	{ "hexForest", forest },
	{ "hexHighlands", highlands },
	{ "hexMountain", mountain },
	{ "hexDunes", dunes },
	{ "hexSwamp", swamp },
	{ "hexLake", lake },
}

app.fs.makeAllDirectories(OUT .. "/src")
local tiles = {}
for bi, biome in ipairs(BIOMES) do
	tiles[biome[1]] = {}
	for v = 0, VARIANTS - 1 do
		local s = bi * 100 + v * 17
		local g, d = buffer(W, H), buffer(W, H)
		biome[2](s, g, d)
		save(string.format("%s%02d", biome[1], v), { { "ground", g }, { "decor", d } })
		tiles[biome[1]][v] = flatten({ g, d })
	end
end
local unders = {}
for v = 0, VARIANTS - 1 do
	unders[v] = underside(900 + v * 13)
	save(string.format("underDirt%02d", v), { { "ground", unders[v] } })
end
for _, theme in ipairs(CASTLE_THEMES) do
	local g, d = buffer(W, H), buffer(W, H)
	castle(77, g, d, theme[2])
	save(theme[1], { { "ground", g }, { "decor", d } })
	tiles[theme[1]:sub(1, -3)] = { [0] = flatten({ g, d }) }
end

-- --- preview: a small island with every biome, scaled up ----------------------------

if PREVIEW then
	local SCALE = 3
	local layout = {
		{ 0, -2, "hexMountain" }, { 1, -2, "hexForest" }, { 2, -2, "hexForest" },
		{ -1, -1, "hexMountain" }, { 0, -1, "hexHighlands" }, { 1, -1, "hexForest" }, { 2, -1, "hexSwamp" },
		{ -2, 0, "hexDunes" }, { -1, 0, "hexDunes" }, { 0, 0, "hexCastle" }, { 1, 0, "hexSwamp" }, { 2, 0, "hexSwamp" },
		{ -2, 1, "hexDunes" }, { -1, 1, "hexDirt" }, { 0, 1, "hexLake" }, { 1, 1, "hexLake" },
		{ -2, 2, "hexMountain" }, { -1, 2, "hexForest" }, { 0, 2, "hexLake" },
	}
	local PW, PH = 300, 290
	local canvas = buffer(PW, PH)
	local sky1, sky2 = hex "1a2236", hex "2b3a58"
	for y = 0, PH - 1 do
		for x = 0, PW - 1 do put(canvas, x, y, dither({ sky1, mix(sky1, sky2, 0.5), sky2 }, y / PH, x, y)) end
	end
	local function center(q, r)
		return math.floor(PW / 2 + R * SQ3 * (q + r / 2) + 0.5), math.floor(PH / 2 + 1.5 * R * r + 0.5)
	end
	local function blit(b, ox, oy)
		for i, c in pairs(b.px) do put(canvas, ox + i % b.w, oy + i // b.w, c) end
	end
	table.sort(layout, function(a, b) return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1]) end)
	for _, t in ipairs(layout) do
		local cx, cy = center(t[1], t[2])
		blit(unders[(t[1] * 7 + t[2] * 13) % VARIANTS], cx - CX, cy + R // 2)
	end
	for _, t in ipairs(layout) do
		local cx, cy = center(t[1], t[2])
		local set = tiles[t[3]]
		blit(set[(t[1] * 7 + t[2] * 13) % VARIANTS] or set[0], cx - CX, cy - CY)
	end
	local img = Image(PW * SCALE, PH * SCALE, ColorMode.RGB)
	for i, c in pairs(canvas.px) do
		local x, y = i % PW, i // PW
		local col = app.pixelColor.rgba(math.floor(c[1]), math.floor(c[2]), math.floor(c[3]), 255)
		for yy = 0, SCALE - 1 do
			for xx = 0, SCALE - 1 do img:drawPixel(x * SCALE + xx, y * SCALE + yy, col) end
		end
	end
	local spr = Sprite(PW * SCALE, PH * SCALE, ColorMode.RGB)
	spr:newCel(spr.layers[1], 1, img, Point(0, 0))
	spr:saveCopyAs(PREVIEW)
	spr:close()
end
