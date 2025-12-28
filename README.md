# peck

`peck` is a screen capture tool for **Wayland**. It provides easy ways to
capture screenshots, record your screen, and optionally convert outputs to
different formats.

`peck` isn't a tool that tries to reinvent the wheel. Rather, it's just a simple
wrapper bash script that makes interfacing with `grim` and `wf-recorder` easier.

## Features

- Capture screenshots or record your screen by region.
- Start and stop recordings easily.
- Save to default directories, temporary directories, or a custom path.
- Copy output directly to the clipboard.
- Convert recordings to various formats (mp4, gif, webm, etc.) using ffmpeg.
- Optionally sends notifications using `libnotify` about the capture status.

## Installation

### Quick setup

1. Install the dependencies.
2. Download `peck` from the
   [releases](https://github.com/codevogel/peck/releases)
3. Optional: Add `peck` to your `$PATH`.
4. Optional: Add keybinds for `peck` to your window manager. (Not required if
   you just want to run `peck` through the CLI.

### Dependencies

Since `peck` is just a simple bash script, be sure to have `bash` installed on
your system.

Then install these external dependencies:

1. [grim](https://github.com/GrimAnticheat/Grim) (for capturing screenshots)
2. [slurp](https://github.com/emersion/slurp) (for grabbing the screen region)
3. [wf-recorder](https://github.com/ammen99/wf-recorder) (for capturing screen
   recordings)
4. [ffmpeg](https://github.com/FFmpeg/FFmpeg) (for converting the screen
   recordings to a desired format)
5. [wl-clipboard](https://github.com/bugaevc/wl-clipboard) (for copying the
   output to the clipboard)

Below are some example instructions for Ubuntu, Arch, and NixOS.

#### Ubuntu

```bash
sudo apt update
sudo apt install -y grim slurp wf-recorder ffmpeg wl-clipboard
```

#### Arch

```bash
sudo pacman -Syu grim slurp wf-recorder ffmpeg wl-clipboard
```

#### NixOS

```nix
# This example uses Home Manager. You can also just use environment.systemPackages
home.packages = with pkgs; [
  grim
  slurp
  wf-recorder
  ffmpeg
  wl-clipboard
];
```

### Download and add peck to your PATH

Download the latest version of `peck` from the releases, then add it to your
`$PATH`.

e.g. on Bash or ZSH:

```bash
curl -L -o some/path/peck https://github.com/codevogel/peck/releases/download/v0.1.0/peck
chmod +x some/path/peck

# If the path where you store peck is not in $PATH, be sure to add it to your path:
echo 'export PATH="some/path:$PATH"' >> ~/.bashrc   # for Bash
source ~/.bashrc
# or
echo 'export PATH="some/path:$PATH"' >> ~/.zshrc    # for Zsh
source ~/.zshrc
```

Verify it runs with `peck --help`.

#### Example install with NixOS

An example `peck.nix` to add to your modules, which installs peck from the
releases page, and installs the dependenceis using home manager:

```nix
{ pkgs, ... }:

let
  peck = pkgs.stdenv.mkDerivation {
    pname = "peck";
    version = "0.1.0";

    src = pkgs.fetchurl {
      url = "https://github.com/codevogel/peck/releases/download/v0.1.0/peck";
      sha256 = "47bfd14c390c6f09e521c864efbd2d7ed608164240d07c6ecf48c2b7677dbabc";
    };

    unpackPhase = ''true'';

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/peck
      chmod +x $out/bin/peck
    '';
  };
in
{
  home.packages = with pkgs; [
    peck

    # Dependencies:
    grim
    slurp
    wf-recorder
    ffmpeg
    wl-clipboard
  ];
}
```

### Integrating peck with your window manager

Add `peck` to your window manager using sensible keybinds. For example, in
Hyprland:

```hypr
bind=$mainMod SHIFT, S, exec, ~/work/peck/peck --clipboard --temp
bind=$mainMod SHIFT, R, exec, ~/work/peck/peck --record --clipboard --temp
bind=$mainMod SHIFT, G, exec, ~/work/peck/peck --record --clipboard --temp --format=gif
```

This would set `SUPER+SHIFT+[S|R|G]` to capture a screenshot, recording, or gif
respectively, instructing peck to store the file in a temporary dir (which is
cleared upon next invocation), and copy the output file to the clipboard, ready
for pasting.

`peck` stops recording when invoked again while recording, so to end a
recording, just hit `SUPER+SHIFT+[R|G]` again while recording.

## Usage

Recommended usage is by integrating peck into your window manager as above, but
you can also run `peck` through the CLI.

Below are some examples that show how to use `peck`.

### Basic Screenshot

```bash
peck
```

Captures a screenshot and saves it to the default screenshot directory.

### Screenshot with Custom Path

```bash
peck ./foo.png
peck bar/baz
```

Stores the screenshot to the specified path.

### Recording

```bash
peck --record
```

Start screen recording. Stop recording with `CTRL-C` or by running `peck` again.

### Recording with Format Conversion

```bash
peck --record --format=gif
```

Record your screen and convert the recording to a GIF.

### Temporary Screenshot to Clipboard

```bash
peck --temp --clipboard
```

Capture a screenshot, store it temporarily in `/tmp/`, and copy it to the
clipboard.

### Recording with Custom ffmpeg Filter

```bash
peck --record --format webm --filter "fps=30,scale=1280:-1:flags=lanczos"
```

Record and convert using a custom ffmpeg filter.

## Command-line Options

| Flag                      | Short | Description                                                                                                                                                          |
| ------------------------- | ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--clipboard`             | `-c`  | Copy the output file to the clipboard.                                                                                                                               |
| `--record`                | `-r`  | Record instead of screenshot.                                                                                                                                        |
| `--temp`                  | `-t`  | Store the file in `/tmp/peck/out`. This is cleared upon each invocation of peck, so captures don't clog up your filesystem.                                          |
| `--format <file_format>`  | `-f`  | Override output format (`png, ppm, jpeg`for screenshots, `mp4, gif` for recordings). Also allows for other recording formats, but these may need `--filter` to work. |
| `--filter <video_filter>` | `-F`  | Custom ffmpeg filter for video conversion.                                                                                                                           |

## Environment Variables

| Variable                       | Default            | Description                                                                                  |
| ------------------------------ | ------------------ | -------------------------------------------------------------------------------------------- |
| `PECK_SCREENSHOT_DIR`          | `$HOME/Pictures`   | Directory to save screenshots in when no file path is provided. Created if it doesn't exist. |
| `PECK_RECORDING_DIR`           | `$HOME/Recordings` | Directory to save recordings in when no file path is provided. Created if it doesn't exist.  |
| `PECK_SCREENSHOT_FORMAT`       | `png`              | Screenshot output format: `png`, `ppm`, `jpeg`.                                              |
| `PECK_RECORDING_FORMAT`        | `mp4`              | Recording output format (initially mp4, then converted).                                     |
| `PECK_SILENCE_NOTIFICATIONS`   | `false`            | Disable libnotify notifications.                                                             |
| `PECK_SILENCE_START_RECORDING` | `false`            | Disable notification when recording starts.                                                  |

## License

MIT Licensed. See [LICENSE](./LICENSE).
