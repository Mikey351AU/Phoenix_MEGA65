Phoenix for MEGA65
==================

A port of the MiSTer Phoenix arcade core
([Arcade-Phoenix_MiSTer](https://github.com/MiSTer-devel/Arcade-Phoenix_MiSTer), by Dar and Sorgelig)
to the MEGA65, built on the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework
(by sy2002 and MJoergen). The original framework README is in `M2M-README.md`.

Status: **V0.2 (adds screen rotation). Builds with Vivado 2022.2 (timing met) and runs on a MEGA65 R6.**

Tested on a MEGA65 R6 over HDMI: ROMs load, the picture is upright with the default "Rotate CW"
setting, and the sound is right. The VGA output has not been tested yet.

R3/R3A: `release/phoenix_r3.cor` builds (timing met) but has not been tested on an R3 yet. The R4/R5
projects are set up the same way but have not been built or tested.

Project layout
--------------

| Path                         | What it is                                                                 |
|------------------------------|----------------------------------------------------------------------------|
| `CORE/Phoenix_MiSTer/`       | The MiSTer core's `rtl/` (unchanged except the note below), MRAs, readme   |
| `CORE/vhdl/main.vhd`         | Phoenix wrapper: controls, reset, video re-sampling into the 44 MHz domain |
| `CORE/vhdl/rotate.vhd`       | Screen rotation: double frame buffer in BRAM, frame locked output raster   |
| `CORE/vhdl/mega65.vhd`       | Clocks, dip switches from the menu, ROM loader, video/audio settings       |
| `CORE/vhdl/clk.vhd`          | MMCM: 11 MHz (Phoenix) + 44 MHz (video), both exact                         |
| `CORE/vhdl/dpram.vhd`        | Vivado replacement for the MiSTer `dpram.vhd` (Intel `altsyncram`)         |
| `CORE/vhdl/keyboard.vhd`     | MEGA65 key mapping                                                         |
| `CORE/vhdl/globals.vhd`      | Clock speed, OSM size, list of auto-loaded ROM files                       |
| `CORE/vhdl/config.vhd`       | Welcome screen, help, options menu                                         |
| `CORE/CORE-R3..R6.xpr`       | Vivado projects for the MEGA65 board revisions R3/R3A, R4, R5, R6          |
| `sdcard/`                    | Files to copy to the root of your SD card                                  |

Changes to the MiSTer sources: in `rtl/phoenix.vhd` the five `xxx : work.dpram` instantiations were
changed to `xxx : entity work.dpram` (Quartus accepts the short form, Vivado does not). The MiSTer
`rtl/dpram.vhd`, `rtl/hiscore.v` and `rtl/pause.v` are not part of the Vivado projects.

How the port works
------------------

* **Clocks:** Phoenix runs at 11 MHz exactly like on MiSTer (`clk_sys`). Video is re-sampled at
  44 MHz (MiSTer's `clk_44`). Both clocks come from one MMCM (100 MHz / 5 * 44 = 880 MHz VCO).
* **Video:** Phoenix's visible area is 239 x 208 pixels at 5.5 MHz, ~59.6 Hz, 15.6 kHz (the same
  window MiSTer uses: `arcade_video` WIDTH 239). The video stream to M2M runs at 11 MHz
  (`video_ce_o`; `video_ce_ovl_o` = 22 MHz), like MiSTer's `arcade_video`. HDMI goes through the
  M2M scaler, and VGA is scan-doubled to 31 kHz.
* **Rotation** (`rotate.vhd`, menu "Screen": Rotate CW (default) / Rotate CCW / No rotation):
  Phoenix writes every frame into one half of a double frame buffer in block RAM, while the other
  half is read out rotated. The output raster has exactly the same frame period as Phoenix
  (704 x 262 at 11 MHz = 2 x 352 x 262) and restarts on every finished input frame. So it is frame
  locked, tear free, one frame of latency, and still 15.6 kHz for the scandoubler.
  M2M always stretches the core's picture to a 4:3 box on HDMI, so the rotated 208 x 239 image is
  placed in the middle of a 356 x 239 box with black pillars. 356 = 4/3 x 208 x 478/373 gives the
  same aspect ratio as MiSTer's "Original" setting for this core (373:478 rotated).
  The OSM (VGA_DX x VGA_DY = 352 x 416, 22 x 26 characters) fits into both orientations on VGA.
  A cycle model of `rotate.vhd` driven by a model of `phoenix_video.vhd` was checked for both
  directions: every rotated pixel comes from the right source pixel, and the output stays locked.
* **ROMs:** the M2M firmware auto-loads the 12 files of the MAME `phoenix` set at startup. Each file
  has its own QNICE device id (`0x0100` .. `0x010B`). `mega65.vhd` turns device + offset into
  Phoenix's `dn_addr` (file n -> `n * 0x800`), which is exactly the layout of the MiSTer `.mra`, and
  hands each byte to the 11 MHz domain with an `xpm_cdc_handshake` (QNICE is stalled until the byte
  has been written). Phoenix is held in reset while ROMs are loading.
* **Audio:** 12-bit unsigned mono -> 16-bit signed on both channels.

Installing
----------

1. Copy the `sdcard/arcade` folder to the root of the MEGA65 SD card (the empty `phxcfg` file
   enables saving the menu settings).
2. Unzip the MAME ROM set `phoenix.zip` (Amstar, set 1) into `/arcade/phoenix/`. These 12 files
   must be there (names as used by the MiSTer MRA, MAME 0.220):

   `ic45` `ic46` `ic47` `ic48` `h5-ic49.5a` `h6-ic50.6a` `h7-ic51.7a` `h8-ic52.8a`
   `ic23.3d` `ic24.4d` `b1-ic39.3b` `b2-ic40.4b`

   If your MAME set uses other file names, either rename the files or change `ROM_00` .. `ROM_11` in
   `CORE/vhdl/globals.vhd`. A missing file stops the core with an error message showing its name.
3. Flash `release/phoenix_r6.cor` (MEGA65 R6) or `release/phoenix_r3.cor` (R3/R3A, not yet tested
   on hardware) with the MEGA65 core menu.

Controls
--------

| MEGA65 keyboard        | Joystick (port 1 or 2) | Phoenix          |
|------------------------|------------------------|------------------|
| Cursor left / right    | Left / right           | Move             |
| Space                  | Fire                   | Fire (auto-fire) |
| Cursor up, right Shift | Up                     | Barrier (shield) |
| 5                      |                        | Insert coin      |
| 1 / 2                  |                        | Start 1P / 2P    |
| Help                   |                        | Options menu     |

The options menu sets screen rotation, lives, bonus life, cocktail cabinet, flip screen, HDMI mode,
CRT emulation, zoom and audio filter. The core is paused while a menu is open.

"Rotate CW" (the default) shows Phoenix upright on a normal monitor. "Rotate CCW" turns it the
other way, and "No rotation" is for a monitor that is physically turned on its side.

Building
--------

The M2M build runs a bash script (`CORE/m2m-rom/make_rom.sh`) from Vivado's pre-synthesis hook
to assemble the QNICE firmware. On Linux it runs directly. With **Vivado for Windows**,
`synth_pre.tcl` runs it through WSL instead, so you need Vivado 2022.2 for Windows plus WSL with Ubuntu.

Clone with the QNICE submodule:

```bash
git clone --recursive <this repository's URL>
```

Windows, one-time setup (in `build\`):

```bash
wsl bash ./setup_wsl.sh
```

Build the bitstream and the `.cor` for your board (writes `release\phoenix_r6.bit` and
`release\phoenix_r6.cor`; `-Board R3` for the R3/R3A; `build_r6.ps1` is a shortcut for R6):

```bash
powershell -ExecutionPolicy Bypass -File .\build.ps1 -Board R6
```

`build.ps1` makes the `.cor` with `bit2core` from
[mega65-tools](https://github.com/MEGA65/mega65-tools) (copied into `build/m65_bit2core`, LGPL v3,
built automatically in WSL). It writes the current core header with the board model (`mega65r6`,
model id `0x06`), core size and CRC32, which the MEGA65 flash menu needs. The `bit2core` that comes
with QNICE writes an older header without these, and its `.cor` files are not listed by the flash
menu (`-OldHeader` still selects it).

Linux: run `M2M/QNICE/tools/make-toolchain.sh` once, then open `CORE/CORE-R6.xpr` (or R3/R4/R5)
in Vivado and generate the bitstream.

Known limitations / TODO
------------------------

* Rotated VGA output has only 23 lines of vertical blanking (46 after the scandoubler). Most
  monitors are fine with that; if yours is not, use "No rotation" on VGA.
* "HDMI: Zoom-in" stretches the 4:3 box to the full 16:9 width, which distorts the rotated picture.
* Pleiads (same hardware family) is not supported yet. It needs its own ROM list and the Pleiads
  sound/palette differences.
* High score saving (MiSTer `hiscore.v`) is not ported, and is not planned.
* Tested so far only on a MEGA65 R6, over HDMI.

License
-------

GPL v3 (MiSTer2MEGA65), the Phoenix core sources keep their original licenses.
