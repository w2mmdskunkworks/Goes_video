# GOES-19 Video Processing Pipeline

This repository/script processes GOES-19 satellite imagery received via HRIT (High Rate Information Transmission) into smooth, annotated video loops. It fetches full-disk false-color images from a remote receiver, enhances them with Sanchez, adds watermarks and timestamps, and compiles them into MP4 videos suitable for YouTube or social media.

## Overview

The `makeGOESvideos.sh` script automates the entire workflow:

1. **Fetch** 5 days of raw full-disk false-color images from a remote GOES-19 receiver
2. **Enhance** images using Sanchez (false-color geostationary satellite compositor)
3. **Annotate** with watermarks and timestamps using ImageMagick
4. **Compile** into smooth 20 FPS MP4 videos using FFmpeg

The result is a 5-day time-lapse video showing GOES-19 full-disk false-color imagery over the Americas, with world map underlay and custom annotations.

## System Requirements

- **Hardware**: Raspberry Pi 4 (4GB+) recommended for smooth processing
- **OS**: Raspberry Pi OS (64-bit) or Debian 12
- **Dependencies**:
  ```bash
  sudo apt install imagemagick ffmpeg openssh-client jq
  ```
- **Sanchez**: v1.0.26.1 ARM binary (pre-installed)
- **Receiver**: Remote GOES-19 HRIT receiver running goesrecv + goesproc
- **Network**: SSH access to receiver at `192.168.50.146`

## Prerequisites

### 1. GOES-19 Receiver Setup
Your receiver should be configured with these files (example configs provided):

**goesrecv.conf** (demodulator settings):
```ini
[demodulator]
mode = "hrit"
source = "rtlsdr"
[rtlsdr]
frequency = 1694100000  # GOES-19 HRIT frequency
sample_rate = 2000000
gain = 5
bias_tee = true
[decoder.packet_publisher]
bind = "tcp://0.0.0.0:5004"
```

**goesproc.conf** (image processing & naming):
```toml
# Full disk false-color (ch02 + ch13 combination)
[[handler]]
type = "image"
product = "goes19"
regions = ["fd"]
channels = ["ch02", "ch13"]
directory = "/media/pi/M21/goes19/fd/fc/{time:%Y-%m-%d}"
filename = "GOES19_fd_fc_{time:%Y%m%dT%H%M%SZ}"
format = "jpg"
```

Images are stored in: `/media/pi/M21/goes19/fd/fc/YYYY-MM-DD/GOES19_fd_fc_YYYYMMDDTHHMMSSZ.jpg`

### 2. Sanchez Configuration
Edit `/home/pi/sanchez/output/Resources/Satellites.json` to include GOES-19 support:

```json
{
  "DisplayName": "GOES-19",
  "FilenamePrefix": "GOES19_fd_fc_",
  "FilenameParser": "Goesproc",
  "Longitude": -75.2,
  "Brightness": 0.95
}
```

### 3. Watermark Images
Place your watermark PNGs in `/home/pi/`:
- `skunkworks20neg.jpg` (full-disk false-color watermark)
- `skunkworks15neg.jpg` (mesoscale watermark)
- `skunkworks10neg.jpg` (mesoscale false-color)
- `skunkworks2.jpg` (IR channels)
- `skunkworks1.jpg` (water vapor)
- `skunkworks5.jpg` (derived products)
- `skunkworks20.jpg` (SST/RRQPE)

### 4. Output Directories
- `/home/pi/workspace/` (temporary processing space)
- `/home/pi/current_jpg/` (latest frame for web display)
- `/home/pi/sanchez/output/` (Sanchez binary and resources)

## Installation

1. **Clone/Place the Script**:
   ```bash
   wget -O /home/pi/makeGOESvideos.sh <script-url>
   chmod +x /home/pi/makeGOESvideos.sh
   ```

2. **Create Working Directories**:
   ```bash
   mkdir -p /home/pi/workspace/{fd_enhance,fd_enhance_out}
   mkdir -p /home/pi/current_jpg
   ```

3. **Install Dependencies**:
   ```bash
   sudo apt update
   sudo apt install -y imagemagick ffmpeg openssh-client jq
   ```

4. **Configure SSH Access**:
   Ensure passwordless SSH to the receiver:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/goesrecv -N ""
   ssh-copy-id -i ~/.ssh/goesrecv.pub pi@192.168.50.146
   ```

## Usage

Run the script with default parameters (5 days of full-disk false-color):

```bash
cd /home/pi
./makeGOESvideos.sh
```

### Command Line Parameters

```bash
./makeGOESvideos.sh <filepath> <output> <framerate> <days>
```

- `<filepath>`: Receiver path (`fd/fc` for full-disk false-color, `m1/ch13` for mesoscale, etc.)
- `<output>`: Video filename base (`fd_fc`, `m1_ir`, etc.)
- `<framerate>`: FPS (10-30 recommended; 20 is default)
- `<days>`: Days of data (1-7; 5 is default)

### Configuration Variables (inside script)

Edit these lines near the top to customize:

```bash
FILEPATH='fd/fc'          # Source channel/folder
OUTPUTPATH='fd_fc'        # Output filename base
FRAMERATE=20              # Video framerate
MAXFOLDERS=5              # Days of data
TAGFILES='true'           # Add watermarks/timestamps
US_ONLY='false'           # US-only crop (requires Sanchez reproject)
```

## Workflow

### Step 1: Data Acquisition (5-10 minutes)
- SSH to receiver at `192.168.50.146`
- Lists the 5 most recent date folders in `/media/pi/M21/goes19/fd/fc/`
- SCP downloads all `.jpg` files from each folder to `/home/pi/workspace/`
- **Files created**: `GOES19_fd_fc_YYYYMMDDTHHMMSSZ.jpg` (144 files per day)

### Step 2: Preprocessing (30 seconds)
- Removes overnight frames (T00-T05 UTC) and solar flare frames (05:30 UTC)
- **Files deleted**: `GOES*0530*.jpg`, `GOES*M1_FC_T0*.jpg`, etc.
- ~100 valid frames remain per day

### Step 3: Sanchez Enhancement (3-5 minutes per day)
- Copies raw images to `/home/pi/workspace/fd_enhance/`
- Removes zero-length files
- Runs Sanchez with world map underlay:
  ```bash
  /home/pi/sanchez/output/Sanchez -s "GOES*" -v -u "world.200411.3x10848x5424.jpg" -o fd_enhance_out
  ```
- Sanchez applies:
  - Georeferencing to world map
  - Atmospheric correction (0.6)
  - Bilinear interpolation to 4km resolution
  - IR tinting and normalization
- **Output**: Enhanced images in `/home/pi/workspace/fd_enhance_out/00000.jpg`, `00001.jpg`, etc.
- Copies enhanced files back to workspace, deletes originals

### Step 4: Annotation (1-2 minutes)
- For each enhanced image, if it matches GOES-19 patterns:
  - Adds watermark (composite with `skunkworks20neg.jpg`)
  - Overlays timestamp (convert with helvetica font, 70pt white text)
- **File naming**:
  - Input: `00000.jpg` → Output: `text_00000.jpg`
- **Supported image types**:
  - `GOES19_fd_fc_*`: Full-disk false-color (50% watermark, center timestamp)
  - `GOES19_fd_ch13`: Full-disk IR (40% watermark, 800px offset)
  - `GOES19_m1_ch*`: Mesoscale-1 (various channels, smaller text)
  - `GOES19_m2_*`: Mesoscale-2 (similar to M1)

### Step 5: Video Compilation (2-3 minutes)
- Resizes annotated frames to 640x640 (ImageMagick)
- Creates animated GIF at 20 FPS (ImageMagick)
- Converts to smooth MP4 with motion interpolation (FFmpeg minterpolate)
- **Final output**:
  - `GOEStemp.gif` (intermediate)
  - `fd_fc.gif` (final GIF)
  - `fd_fc_20.mp4` (final video)
- Copies latest frame to `/home/pi/current_jpg/current_fd_fc.jpg`

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `fd_fc_20.mp4` | `/home/pi/workspace/` | 5-day full-disk false-color video (20 FPS, ~2-3 min) |
| `fd_fc.gif` | `/home/pi/workspace/` | Animated GIF version |
| `current_fd_fc.jpg` | `/home/pi/current_jpg/` | Latest enhanced frame (for web display) |
| `text_*.jpg` | `/home/pi/workspace/` (temporary) | Annotated frames (deleted after video creation) |

## Customization

### Watermark Positioning
Adjust ImageMagick parameters in the annotation section:

```bash
# Watermark opacity and position
composite -watermark 50% -gravity northeast watermark.jpg input.jpg output.jpg

# Text position and size
convert output.jpg -font helvetica -fill white -pointsize 70 \
  -gravity center -annotate +0+1000 "timestamp" final.jpg
```

### Video Settings
Modify near the end of the script:

```bash
# Resolution (640x640 is Pi-safe)
convert 'text*.jpg[640x]' resized_%05d.jpg

# Framerate and smoothing
convert -loop 0 -delay $FRAMERATE resized_*.jpg GOEStemp.gif
ffmpeg -y -i GOEStemp.gif -filter "minterpolate='mi_mode=blend'" \
  -c:v libx264 -pix_fmt yuv420p output.mp4
```

### US-Only Crop
Set `US_ONLY='true'` to crop to continental US:
```bash
US_ONLY='true'  # Adds --lon -144:-44 --lat 9:54 to Sanchez
```
Output becomes `US_fd_fc_20.mp4`.

## Troubleshooting

### Common Issues

#### 1. "Unable to find filename parser"
- **Cause**: Missing GOES-19 entry in `Satellites.json`
- **Fix**: Add the GOES-19 configuration shown in Prerequisites

#### 2. "FileNotFoundException" in Sanchez
- **Cause**: Zero-byte or corrupted JPEGs from receiver
- **Fix**: The script already removes zero-byte files. For corrupted ones:
  ```bash
  find /home/pi/workspace/fd_enhance -type f ! -exec file {} \; | grep -v "JPEG" | xargs rm -f
  ```

#### 3. "Cache resources exhausted" (ImageMagick)
- **Cause**: Insufficient RAM for high-resolution processing
- **Fix**: Script uses 640x640 resolution. For more RAM, increase swap:
  ```bash
  sudo dphys-swapfile swapoff
  sudo nano /etc/dphys-swapfile  # conf_SWAPSIZE=2048
  sudo dphys-swapfile setup
  sudo dphys-swapfile swapon
  ```

#### 4. SSH Connection Failed
- **Cause**: No passwordless SSH to receiver
- **Fix**: Generate and copy SSH key (see Installation)

#### 5. No Files Copied from Receiver
- **Cause**: Empty or incorrect path on receiver
- **Fix**: Verify path exists:
  ```bash
  ssh pi@192.168.50.146 "ls -la /media/pi/M21/goes19/fd/fc/"
  ```

#### 6. Video is Empty or 1-Frame
- **Cause**: No valid images after Sanchez
- **Fix**: Check Sanchez output directory:
  ```bash
  ls -la /home/pi/workspace/fd_enhance_out/
  ```
  If empty, verify `Satellites.json` and input files.

### Debug Mode

Add `set -x` after `#!/usr/bin/env bash` to enable verbose debugging:

```bash
#!/usr/bin/env bash
set -x  # Debug mode - prints every command
```

Run and check the output for specific failures.

### Log Files

Redirect output to a log:
```bash
./makeGOESvideos.sh > goes_video_$(date +%Y%m%d_%H%M%S).log 2>&1
```

## Performance

| Operation | Time (5 days, ~500 images) | RAM Usage | CPU Usage |
|-----------|----------------------------|-----------|-----------|
| Data fetch | 2-5 min | <100MB | Low |
| Sanchez enhancement | 15-25 min | 800MB-1.2GB | High |
| Annotation | 1-2 min | 200MB | Medium |
| Video compilation | 2-3 min | 300MB | Medium |
| **Total** | **20-35 min** | **Peak: 1.2GB** | **High during Sanchez** |

**Tips for faster processing**:
- Reduce `MAXFOLDERS=1` for testing (1 day = ~5 min total)
- Use Pi 4 (8GB) for 20-30% faster Sanchez processing
- Process only recent data (`MAXFOLDERS=1`) for real-time updates

## Known Limitations

- **Memory Intensive**: Sanchez requires 1GB+ RAM for full-disk processing
- **No Audio**: Videos are silent (satellite imagery only)
- **Fixed Resolution**: Output is 640x640 (Pi-optimized)
- **Single Channel**: Script processes one channel/path at a time
- **No Error Recovery**: If any step fails, the script exits (use log files)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Sanchez**: [github.com/nullpainter/sanchez](https://github.com/nullpainter/sanchez) - False-color geostationary satellite image compositor
- **goestools**: [github.com/pietern/goestools](https://github.com/pietern/goestools) - GOES-19 HRIT receiver/decoder
- **ImageMagick**: Image processing and annotation
- **FFmpeg**: Video compilation and motion interpolation
- **Natural Earth**: World map underlay data

## Support

- **Issues**: Create an issue on GitHub
- **Discussions**: Join the GOES reception community on Discord/Reddit
- **Satellite Data**: NOAA GOES-19 documentation [here](https://www.goes-r.gov/)

---

*Last updated: January 16, 2026*  
*Tested on: Raspberry Pi OS 64-bit, Sanchez v1.0.26.1*
