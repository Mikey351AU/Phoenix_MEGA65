using System;
using System.Collections.Generic;

// Cycle model (one step = one rising edge of the 11 MHz clock) of:
//   Phoenix rtl/phoenix_video.vhd + the registered outputs of phoenix.vhd
//   CORE/vhdl/rotate.vhd
// Pixel "colors" are replaced by a payload = (native line << 16) | native column, so the
// rotated output can be checked pixel by pixel.
public static class RotSim
{
    static int B(int v, int k) { return (v >> (k - 1)) & 1; }

    public static string Run(bool ccw, int frames)
    {
        // generics of rotate.vhd
        const int SRC_DX = 239, SRC_DY = 208, HTOT = 704, VTOT = 262, BOX = 356;
        const int HS0 = 450, HS1 = 502, VS0 = 245, VS1 = 248;
        int IMG_X0 = (BOX - SRC_DY) / 2;

        // phoenix_video state
        int h = 0, v = 0, hstb = 0, q1 = 0, q2 = 0;
        int hclk = 0;
        // phoenix.vhd output registers
        int o_hblank = 1, o_vblank = 1, o_payload = 0;
        // native coordinate tracking for the payload (independent of rotate.vhd)
        int natLine = -1, natCol = 0, prevAct = 0, prevVbl = 1;

        // rotate.vhd state
        int[] ram = new int[1 << 17];
        int wr_x = 0, wr_y = 0, wr_buf = 0, src_active_d = 0, src_vblank_d = 0;
        int out_x = 0, out_y = 0, rd_buf = 1, rd_data = 0;
        int s1_img = 0, s1_hb = 1, s1_vb = 1, s1_hs = 0, s1_vs = 0;
        int d_rgb = 0, d_hb = 1, d_vb = 1, d_hs = 0, d_vs = 0;

        long cycles = (long)frames * 352 * 262 * 2;
        int lockResets = 0, unnaturalResets = 0;
        int errors = 0, checkedPix = 0, blackOk = 0;
        var report = new List<string>();
        int framesSeen = 0;
        // output frame capture
        int rowsSeenWithDE = 0, deWidthMin = int.MaxValue, deWidthMax = 0, curDeWidth = 0;
        int lastHb = 1;
        

        for (long c = 0; c < cycles; c++)
        {
            // falling edge before this rising edge toggles hclk
            hclk ^= 1;
            int ce = hclk;

            // ---------------- combinational (phoenix_video) ----------------
            int hblank_bg = (1 - (B(h, 9) & q1)) & (1 - (B(h, 9) & q2));
            int v2 = v < 255 ? (v & 0xFF) : 255;
            int b8 = (v2 >> 7) & 1, b7 = (v2 >> 6) & 1, b6 = (v2 >> 5) & 1, b5 = (v2 >> 4) & 1, b4 = (v2 >> 3) & 1;
            int A = b8 & b7 & (1 - b6) & (1 - b5) & (1 - b4);
            int Bv = b8 & b7 & (1 - b6) & (1 - b5) & b4;
            int vblank_n = (1 - (b8 & b7)) | (1 - ((1 - A) & (1 - Bv)));
            int vblank = 1 - vblank_n;

            // ---------------- rotate.vhd combinational ----------------
            int frame_done = (ce == 1 && o_vblank == 1 && src_vblank_d == 0) ? 1 : 0;
            int wr_en = (ce == 1 && o_hblank == 0 && o_vblank == 0 && wr_x < SRC_DX && wr_y < SRC_DY) ? 1 : 0;
            int wr_addr = (wr_buf << 16) | ((wr_y & 0xFF) << 8) | (wr_x & 0xFF);
            int img_x = (out_x >= IMG_X0 && out_x < IMG_X0 + SRC_DY) ? out_x - IMG_X0 : 0;
            int src_x, src_y;
            if (out_y < SRC_DX) {
                if (!ccw) { src_x = out_y; src_y = SRC_DY - 1 - img_x; }
                else      { src_x = SRC_DX - 1 - out_y; src_y = img_x; }
            } else { src_x = 0; src_y = 0; }
            int rd_addr = (rd_buf << 16) | (src_y << 8) | src_x;

            // ---------------- check the rotator output (registered values) ----------------
            if (framesSeen >= 3)
            {
                if (d_hb == 0 && d_vb == 0)
                {
                    curDeWidth++;
                    // which output pixel is this? (outputs are 2 clocks behind out_x/out_y)
                }
                if (lastHb == 0 && d_hb == 1 && d_vb == 0) { deWidthMin = Math.Min(deWidthMin, curDeWidth); deWidthMax = Math.Max(deWidthMax, curDeWidth); rowsSeenWithDE++; curDeWidth = 0; }
            }
            lastHb = d_hb;

            // ---------------- register updates ----------------
            // rotate.vhd p_write
            int n_wr_x = wr_x, n_wr_y = wr_y, n_wr_buf = wr_buf, n_sad = src_active_d, n_svd = src_vblank_d;
            if (ce == 1)
            {
                n_svd = o_vblank;
                n_sad = (o_hblank == 0 && o_vblank == 0) ? 1 : 0;
                if (o_vblank == 1) { n_wr_x = 0; n_wr_y = 0; if (src_vblank_d == 0) n_wr_buf = wr_buf ^ 1; }
                else if (o_hblank == 0) { if (wr_x != 511) n_wr_x = wr_x + 1; }
                else if (src_active_d == 1) { n_wr_x = 0; if (wr_y != 511) n_wr_y = wr_y + 1; }
            }
            // RAM (write and read in the same edge: read returns OLD data, different buffers anyway)
            int n_rd_data = ram[rd_addr];
            if (wr_en == 1) ram[wr_addr] = o_payload;

            // p_read stage 1 / 2
            int n_s1_hb = out_x >= BOX ? 1 : 0;
            int n_s1_vb = out_y >= SRC_DX ? 1 : 0;
            int n_s1_img = (out_x >= IMG_X0 && out_x < IMG_X0 + SRC_DY && out_y < SRC_DX) ? 1 : 0;
            int n_s1_hs = (out_x >= HS0 && out_x < HS1) ? 1 : 0;
            int n_s1_vs = (out_y >= VS0 && out_y < VS1) ? 1 : 0;
            int n_d_rgb = s1_img == 1 ? rd_data : -1;   // -1 = black
            int n_d_hb = s1_hb, n_d_vb = s1_vb, n_d_hs = s1_hs, n_d_vs = s1_vs;

            // checking: the pixel that becomes visible at the output now was addressed 2 edges ago.
            // Simpler: check n_d_rgb against the coordinates that produced s1_* (one edge ago).
            // We keep the previous out_x/out_y in variables below.
            int n_out_x = out_x, n_out_y = out_y, n_rd_buf = rd_buf;
            if (frame_done == 1)
            {
                bool natural = (out_x == HTOT - 1 && out_y == VTOT - 1);
                lockResets++; if (!natural && framesSeen >= 2) unnaturalResets++;
                n_rd_buf = wr_buf; n_out_x = 0; n_out_y = 0;
            }
            else if (out_x == HTOT - 1) { n_out_x = 0; n_out_y = out_y == VTOT - 1 ? 0 : out_y + 1; }
            else n_out_x = out_x + 1;

            // phoenix.vhd output registers (on ce) + payload with the true native coordinates
            int n_o_hb = o_hblank, n_o_vb = o_vblank, n_o_pl = o_payload;
            if (ce == 1)
            {
                int act = (hblank_bg == 0 && vblank == 0) ? 1 : 0;
                if (vblank == 1) { natLine = -1; natCol = 0; }
                else if (act == 1) { if (prevAct == 0) { natLine++; natCol = 0; } }
                if (vblank == 1 && prevVbl == 0) framesSeen++;
                n_o_hb = hblank_bg; n_o_vb = vblank;
                n_o_pl = act == 1 ? ((natLine << 16) | natCol) : 0x7FFF0000;
                if (act == 1) natCol++;
                prevAct = act; prevVbl = vblank;
            }

            // phoenix_video registers (on hclk = '1')
            int nh = h, nv = v, nq1 = q1, nq2 = q2, nhstb = hstb;
            if (hclk == 1)
            {
                int j1 = B(h, 6) & B(h, 4), k1 = hstb;
                int j2 = (1 - B(h, 6)) & B(h, 5), k2 = B(h, 8) & B(h, 7) & B(h, 6) & B(h, 4);
                nq1 = ((j1 ^ k1) == 1) ? j1 : (j1 == 1 ? 1 - q1 : q1);
                nq2 = ((j2 ^ k2) == 1) ? j2 : (j2 == 1 ? 1 - q2 : q2);
                if ((B(h, 3) & B(h, 2) & B(h, 1)) == 1) nhstb = 1 - B(h, 9);
                nh = h + 1;
                if (h == 511) { nh = 160; nv = v == 261 ? 0 : v + 1; }
            }

            // ---- verify the pixel that is registered into the output now (n_d_rgb) ----
            // It belongs to the output coordinates that were current one edge ago (prev_out_*),
            // because s1_img was computed from them and rd_data was read with their address.
            if (framesSeen >= 3 && s1_img == 1)
            {
                int px = prevOutX - IMG_X0, py = prevOutY;
                int ex, ey;
                if (!ccw) { ex = py; ey = SRC_DY - 1 - px; } else { ex = SRC_DX - 1 - py; ey = px; }
                int expected = (ey << 16) | ex;
                checkedPix++;
                if (n_d_rgb != expected) { if (errors < 5) report.Add(string.Format("mismatch at out ({0},{1}): got line {2} col {3}, expected line {4} col {5}", prevOutX, prevOutY, n_d_rgb >> 16, n_d_rgb & 0xFFFF, ey, ex)); errors++; }
            }
            else if (framesSeen >= 3 && n_d_rgb == -1) blackOk++;
            prevOutX = out_x; prevOutY = out_y;

            // commit
            wr_x = n_wr_x; wr_y = n_wr_y; wr_buf = n_wr_buf; src_active_d = n_sad; src_vblank_d = n_svd;
            rd_data = n_rd_data;
            s1_hb = n_s1_hb; s1_vb = n_s1_vb; s1_img = n_s1_img; s1_hs = n_s1_hs; s1_vs = n_s1_vs;
            d_rgb = n_d_rgb; d_hb = n_d_hb; d_vb = n_d_vb; d_hs = n_d_hs; d_vs = n_d_vs;
            out_x = n_out_x; out_y = n_out_y; rd_buf = n_rd_buf;
            o_hblank = n_o_hb; o_vblank = n_o_vb; o_payload = n_o_pl;
            h = nh; v = nv; q1 = nq1; q2 = nq2; hstb = nhstb;
        }

        report.Insert(0, string.Format("{0}: frames={1} lock resets={2} (off-cycle after lock: {3}), image pixels checked={4}, errors={5}, DE width min/max={6}/{7}, DE rows (3+ frames)={8}",
            ccw ? "CCW" : "CW ", framesSeen, lockResets, unnaturalResets, checkedPix, errors, deWidthMin, deWidthMax, rowsSeenWithDE));
        return string.Join(Environment.NewLine, report);
    }
    static int prevOutX = 0, prevOutY = 0;
}
