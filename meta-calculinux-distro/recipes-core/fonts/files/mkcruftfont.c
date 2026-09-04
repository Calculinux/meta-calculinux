/*
 * Build demand-paged cruft .cruftfont blobs from BDF layers or GNU Unifont hex.
 *
 * File layout (little-endian):
 *   magic[8]         "CRUFTFN1"
 *   uint32 cell_w, cell_h, glyph_bytes, page_shift (must be 8)
 *   uint32 page_off[256]   — 0 empty, else file offset of uint32[256] subtable
 *   page tables + glyph records: uint32 code; uint8 width; uint8 pad[3]; uint16 bitmap[cell_h]
 *
 * Usage:
 *   mkcruftfont --self-check
 *   mkcruftfont --cell WxH primary.bdf [secondary.bdf ...] out.cruftfont
 *   mkcruftfont --cell 8x16 unifont.hex out.cruftfont
 */
#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define UCS2_CHARS 0x10000
#define GLYPH_MAX_H 16
#define MAGIC "CRUFTFN1"
#define PAGE_SHIFT 8
#define PAGE_COUNT 256
#define PAGE_MASK  (PAGE_COUNT - 1)

struct glyph_disk {
	uint32_t code;
	uint8_t width;
	uint8_t pad[3];
	uint16_t bitmap[GLYPH_MAX_H];
};

struct glyph_table {
	struct glyph_disk *glyphs;
	int *have;
	size_t n, cap;
	int cell_w;
	int cell_h;
};

static uint8_t bitrev8(uint8_t v)
{
	v = (uint8_t)(((v & 0xF0) >> 4) | ((v & 0x0F) << 4));
	v = (uint8_t)(((v & 0xCC) >> 2) | ((v & 0x33) << 2));
	v = (uint8_t)(((v & 0xAA) >> 1) | ((v & 0x55) << 1));
	return v;
}

static int hexval(char c)
{
	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	return -1;
}

static int parse_hex_byte(const char *s, uint8_t *out)
{
	int hi = hexval(s[0]);
	int lo = hexval(s[1]);

	if (hi < 0 || lo < 0)
		return -1;
	*out = (uint8_t)((hi << 4) | lo);
	return 0;
}

static int parse_hex_bytes(const char *s, uint8_t *out, int nbytes)
{
	for (int i = 0; i < nbytes; i++) {
		if (parse_hex_byte(s + i * 2, out + i) != 0)
			return -1;
	}
	return 0;
}

static size_t glyph_record_bytes(int cell_h)
{
	return 8 + (size_t)cell_h * 2;
}

static void tofu_box(struct glyph_table *t, struct glyph_disk *g, uint32_t code, uint8_t width)
{
	int cw = t->cell_w;
	int ch = t->cell_h;
	uint16_t edge = (uint16_t)((1u << cw) - 1u);
	uint16_t full = (uint16_t)((1u << (cw * 2)) - 1u);

	memset(g, 0, sizeof(*g));
	g->code = code;
	g->width = width;
	for (int h = 0; h < ch; h++) {
		if (width == 1) {
			if (h == 0 || h == ch - 1)
				g->bitmap[h] = edge;
			else
				g->bitmap[h] = (uint16_t)(1u | (1u << (cw - 1)));
		} else {
			if (h == 0 || h == ch - 1)
				g->bitmap[h] = full;
			else
				g->bitmap[h] = (uint16_t)((1u << (cw * 2 - 1)) | 1u);
		}
	}
}

static int glyph_add(struct glyph_table *t, const struct glyph_disk *g)
{
	if (g->code >= UCS2_CHARS)
		return 0;
	if (t->have[g->code])
		return 0;

	if (t->n == t->cap) {
		size_t ncap = t->cap ? t->cap * 2 : 4096;
		struct glyph_disk *ng = realloc(t->glyphs, ncap * sizeof(*ng));

		if (!ng)
			return -1;
		t->glyphs = ng;
		t->cap = ncap;
	}
	t->glyphs[t->n++] = *g;
	t->have[g->code] = 1;
	return 0;
}

/* BDF row (MSB-left) -> cruft LSB-right row; x_off shifts into the cell. */
static uint16_t bdf_row_to_bits(const uint8_t *bytes, int nbytes, int bbw, int x_off, int target_bits)
{
	uint16_t bits = 0;

	for (int x = 0; x < bbw; x++) {
		int cell_x = x + x_off;
		int bi = x / 8;
		int bp = x % 8;

		if (cell_x < 0 || cell_x >= target_bits)
			continue;
		if (bi >= nbytes)
			break;
		if (bytes[bi] & (0x80u >> bp))
			bits |= (uint16_t)(1u << (target_bits - 1 - cell_x));
	}
	return bits;
}

static int load_bdf(const char *path, struct glyph_table *t)
{
	FILE *fp = fopen(path, "r");
	char line[512];
	int encoding = -1, dwidth = 0, bbw = 0, bbh = 0, bbx = 0, bby = 0;
	int font_ascent = t->cell_h; /* baseline at bottom if FONT_ASCENT absent */
	int in_bitmap = 0, row = 0, y_start = 0, glyph_width = 1;
	struct glyph_disk g;
	size_t before = t->n;

	if (!fp) {
		perror(path);
		return -1;
	}

	while (fgets(line, sizeof(line), fp)) {
		char *nl = strchr(line, '\n');

		if (nl)
			*nl = '\0';

		if (!in_bitmap) {
			if (!strncmp(line, "FONT_ASCENT ", 12))
				font_ascent = atoi(line + 12);
			else if (!strncmp(line, "ENCODING ", 9))
				encoding = atoi(line + 9);
			else if (!strncmp(line, "DWIDTH ", 7))
				dwidth = atoi(line + 7);
			else if (!strncmp(line, "BBX ", 4))
				sscanf(line + 4, "%d %d %d %d", &bbw, &bbh, &bbx, &bby);
			else if (!strcmp(line, "BITMAP")) {
				memset(&g, 0, sizeof(g));
				g.code = (uint32_t)encoding;
				glyph_width = (dwidth > t->cell_w) ? 2 : 1;
				g.width = (uint8_t)glyph_width;
				y_start = font_ascent - (bby + bbh);
				in_bitmap = 1;
				row = 0;
			} else if (!strcmp(line, "ENDCHAR")) {
				encoding = -1;
			}
			continue;
		}

		if (!strcmp(line, "ENDCHAR")) {
			if (encoding >= 0 && encoding < UCS2_CHARS && bbh > 0 && row > 0)
				glyph_add(t, &g);
			in_bitmap = 0;
			encoding = -1;
			continue;
		}

		{
			uint8_t bytes[4] = {0};
			int nbytes = 0;
			int dst = y_start + row;
			const char *p = line;

			row++;
			if (dst < 0 || dst >= t->cell_h)
				continue;

			while (*p && nbytes < (int)sizeof(bytes)) {
				if (!isxdigit((unsigned char)p[0]) || !isxdigit((unsigned char)p[1]))
					break;
				if (parse_hex_byte(p, &bytes[nbytes]) != 0)
					break;
				nbytes++;
				p += 2;
			}
			if (nbytes == 0)
				continue;

			g.bitmap[dst] = bdf_row_to_bits(bytes, nbytes, bbw, bbx,
				t->cell_w * glyph_width);
		}
	}

	fclose(fp);
	fprintf(stderr, "BDF %s: +%zu glyphs (total %zu)\n", path, t->n - before, t->n);
	return 0;
}

static void unifont_half_native(const uint8_t src[16], uint16_t *bitmap, int cell_h, int cell_w)
{
	for (int y = 0; y < cell_h; y++) {
		uint8_t s = bitrev8(src[y]);
		uint16_t row = 0;

		for (int x = 0; x < cell_w; x++) {
			if (s & (1u << x))
				row |= (uint16_t)(1u << x);
		}
		bitmap[y] = row;
	}
}

static void unifont_wide_native(const uint8_t src[32], uint16_t *bitmap, int cell_h)
{
	for (int y = 0; y < cell_h; y++) {
		uint8_t left = bitrev8(src[y * 2]);
		uint8_t right = bitrev8(src[y * 2 + 1]);

		bitmap[y] = (uint16_t)(((uint16_t)left << 8) | right);
	}
}

static int load_unifont_hex(const char *path, struct glyph_table *t)
{
	FILE *in = fopen(path, "r");
	char line[256];
	int expect_half = t->cell_w * t->cell_h / 4;
	int expect_wide = t->cell_w * t->cell_h / 2;

	if (!in) {
		perror(path);
		return -1;
	}

	while (fgets(line, sizeof(line), in)) {
		char *colon;
		unsigned int code;
		struct glyph_disk g;
		uint8_t raw[32];
		int len;

		colon = strchr(line, ':');
		if (!colon)
			continue;
		*colon = '\0';
		if (sscanf(line, "%x", &code) != 1 || code >= UCS2_CHARS)
			continue;
		if (t->have[code])
			continue;

		{
			char *nl = strchr(colon + 1, '\n');

			if (nl)
				*nl = '\0';
		}

		len = (int)strlen(colon + 1);
		memset(&g, 0, sizeof(g));
		g.code = code;

		if (len == expect_half) {
			if (parse_hex_bytes(colon + 1, raw, t->cell_h) != 0)
				continue;
			g.width = 1;
			unifont_half_native(raw, g.bitmap, t->cell_h, t->cell_w);
		} else if (len == expect_wide) {
			if (parse_hex_bytes(colon + 1, raw, t->cell_h * 2) != 0)
				continue;
			g.width = 2;
			unifont_wide_native(raw, g.bitmap, t->cell_h);
		} else {
			continue;
		}

		if (glyph_add(t, &g) < 0) {
			fclose(in);
			return -1;
		}
	}

	fclose(in);
	fprintf(stderr, "Unifont hex: %zu glyphs total\n", t->n);
	return 0;
}

static int parse_cell(const char *spec, int *w, int *h)
{
	if (sscanf(spec, "%dx%d", w, h) != 2 || *w <= 0 || *h <= 0 || *h > GLYPH_MAX_H)
		return -1;
	/* half-width bits fit in uint16 when 2*cell_w <= 16 */
	if (*w > 8)
		return -1;
	if ((*w == 4 && *h == 8) || (*w == 6 && *h == 12) || (*w == 8 && *h == 16))
		return 0;
	fprintf(stderr, "unsupported cell size %dx%d (want 4x8, 6x12, or 8x16)\n", *w, *h);
	return -1;
}

static int self_check(void)
{
	struct glyph_table t48 = { .cell_w = 4, .cell_h = 8 };
	struct glyph_table t612 = { .cell_w = 6, .cell_h = 12 };
	struct glyph_table t816 = { .cell_w = 8, .cell_h = 16 };
	struct glyph_disk g;
	uint8_t raw[16];

	if (glyph_record_bytes(8) != 24 || glyph_record_bytes(12) != 32 || glyph_record_bytes(16) != 40)
		return 1;

	memset(raw, 0, sizeof(raw));
	raw[4] = 0x10;
	unifont_half_native(raw, g.bitmap, 8, 8);
	if (g.bitmap[4] != 0x08)
		return 2;

	t48.have = calloc(UCS2_CHARS, sizeof(int));
	t612.have = calloc(UCS2_CHARS, sizeof(int));
	t816.have = calloc(UCS2_CHARS, sizeof(int));
	if (!t48.have || !t612.have || !t816.have)
		return 3;

	tofu_box(&t48, &g, 0x3f, 1);
	if (g.bitmap[0] != 0x0f)
		return 4;

	tofu_box(&t612, &g, 0x3f, 1);
	if (g.bitmap[0] != 0x3f)
		return 5;

	tofu_box(&t816, &g, 0x3000, 2);
	if (g.bitmap[0] != 0xffff)
		return 6;

	free(t48.have);
	free(t612.have);
	free(t816.have);
	fprintf(stderr, "mkcruftfont: self-check ok (4x8=%zu B, 6x12=%zu B, 8x16=%zu B records)\n",
		glyph_record_bytes(8), glyph_record_bytes(12), glyph_record_bytes(16));
	return 0;
}

static int write_u32(FILE *fp, uint32_t v)
{
	uint8_t b[4] = { v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff };

	return fwrite(b, 1, 4, fp) == 4 ? 0 : -1;
}

static int write_u16(FILE *fp, uint16_t v)
{
	uint8_t b[2] = { v & 0xff, (v >> 8) & 0xff };

	return fwrite(b, 1, 2, fp) == 2 ? 0 : -1;
}

static int write_glyph(FILE *fp, const struct glyph_disk *g, int cell_h)
{
	if (write_u32(fp, g->code))
		return -1;
	if (fputc(g->width, fp) == EOF)
		return -1;
	if (fputc(0, fp) == EOF || fputc(0, fp) == EOF || fputc(0, fp) == EOF)
		return -1;
	for (int i = 0; i < cell_h; i++) {
		if (write_u16(fp, g->bitmap[i]))
			return -1;
	}
	return 0;
}

static int write_blob(const char *outpath, struct glyph_table *t)
{
	uint32_t *glyph_off;
	uint32_t page_off[PAGE_COUNT];
	uint32_t header_size;
	uint32_t cursor;
	int page_used[PAGE_COUNT];
	size_t rec_bytes = glyph_record_bytes(t->cell_h);
	size_t page_table_bytes = PAGE_COUNT * sizeof(uint32_t);
	FILE *out;
	int pages = 0;

	glyph_off = calloc(UCS2_CHARS, sizeof(uint32_t));
	if (!glyph_off)
		return -1;

	memset(page_off, 0, sizeof(page_off));
	memset(page_used, 0, sizeof(page_used));

	for (size_t i = 0; i < t->n; i++)
		page_used[t->glyphs[i].code >> PAGE_SHIFT] = 1;

	header_size = 8 + 16 + PAGE_COUNT * 4;
	cursor = header_size;
	for (int p = 0; p < PAGE_COUNT; p++) {
		if (!page_used[p])
			continue;
		page_off[p] = cursor;
		cursor += (uint32_t)page_table_bytes;
		pages++;
	}

	for (size_t i = 0; i < t->n; i++) {
		glyph_off[t->glyphs[i].code] = cursor;
		cursor += (uint32_t)rec_bytes;
	}

	out = fopen(outpath, "wb");
	if (!out) {
		perror(outpath);
		free(glyph_off);
		return -1;
	}

	if (fwrite(MAGIC, 1, 8, out) != 8 ||
	    write_u32(out, (uint32_t)t->cell_w) || write_u32(out, (uint32_t)t->cell_h) ||
	    write_u32(out, (uint32_t)rec_bytes) || write_u32(out, PAGE_SHIFT)) {
		fclose(out);
		free(glyph_off);
		return -1;
	}

	for (int p = 0; p < PAGE_COUNT; p++) {
		if (write_u32(out, page_off[p])) {
			fclose(out);
			free(glyph_off);
			return -1;
		}
	}

	for (int p = 0; p < PAGE_COUNT; p++) {
		if (!page_used[p])
			continue;
		for (int i = 0; i < PAGE_COUNT; i++) {
			uint32_t code = ((uint32_t)p << PAGE_SHIFT) | (uint32_t)i;

			if (write_u32(out, glyph_off[code])) {
				fclose(out);
				free(glyph_off);
				return -1;
			}
		}
	}

	for (size_t i = 0; i < t->n; i++) {
		if (write_glyph(out, &t->glyphs[i], t->cell_h)) {
			fclose(out);
			free(glyph_off);
			return -1;
		}
	}

	fclose(out);
	fprintf(stderr, "wrote %zu glyphs (%d pages, ~%u KiB, cell %dx%d, record %zu B)\n",
		t->n, pages, cursor / 1024, t->cell_w, t->cell_h, rec_bytes);
	free(glyph_off);
	return 0;
}

static void usage(const char *prog)
{
	fprintf(stderr, "usage: %s --self-check\n", prog);
	fprintf(stderr, "       %s --cell WxH a.bdf [b.bdf ...] out.cruftfont\n", prog);
	fprintf(stderr, "       %s --cell 8x16 unifont.hex out.cruftfont\n", prog);
}

int main(int argc, char **argv)
{
	struct glyph_table t = {0};
	static const uint32_t need[] = { 0x20, 0x3f, 0x3000 };
	int hex_mode;

	if (argc == 2 && !strcmp(argv[1], "--self-check"))
		return self_check();

	if (argc < 5 || strcmp(argv[1], "--cell") != 0 || parse_cell(argv[2], &t.cell_w, &t.cell_h) != 0) {
		usage(argv[0]);
		return 1;
	}

	hex_mode = (argc == 5 && strstr(argv[3], ".hex") != NULL);
	if (!hex_mode && argc < 5) {
		usage(argv[0]);
		return 1;
	}
	if (hex_mode && !(t.cell_w == 8 && t.cell_h == 16)) {
		fprintf(stderr, "Unifont hex import requires --cell 8x16\n");
		return 1;
	}

	t.have = calloc(UCS2_CHARS, sizeof(int));
	if (!t.have)
		return 1;

	if (hex_mode) {
		if (load_unifont_hex(argv[3], &t) < 0)
			goto fail;
	} else {
		for (int i = 3; i < argc - 1; i++) {
			if (load_bdf(argv[i], &t) < 0)
				goto fail;
		}
	}

	for (size_t i = 0; i < sizeof(need) / sizeof(need[0]); i++) {
		struct glyph_disk g;

		if (t.have[need[i]])
			continue;
		tofu_box(&t, &g, need[i], need[i] == 0x3000 ? 2 : 1);
		if (glyph_add(&t, &g) < 0)
			goto fail;
	}

	if (write_blob(argv[argc - 1], &t) < 0)
		goto fail;

	free(t.glyphs);
	free(t.have);
	return 0;

fail:
	free(t.glyphs);
	free(t.have);
	return 1;
}
