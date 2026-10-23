Self-contained WaBiBaBuSy Linux client (no .NET install needed). Pick the tarball for your CPU.

```bash
tar xzf wabibabusy-client-linux-x64.tar.gz
bash wabibabusy-client-linux-x64/packaging/install.sh          # add --args "--server 192.168.1.10" to skip discovery
wabibabusy-client --demo                                        # check placement without a server, Ctrl+C to quit
```

Needs X11 libraries (present on any desktop install). On KDE Plasma 6 the installer also sets up a KWin script that
keeps the wallpaper above Plasma's desktop. Full notes: [`.docs/LINUX_CLIENT.md`](https://github.com/dainikkal/WaBiBaBuSy/blob/main/.docs/LINUX_CLIENT.md).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Permission denied` | Start the installer with `bash …/packaging/install.sh`; it fixes the file modes itself. |
| Missing libraries (`Unable to load shared library 'libX11.so.6'`, or a warning from `install.sh`) | Fedora: `sudo dnf install libX11 libXrandr libXext libICE libSM fontconfig`<br>Ubuntu/Debian: `sudo apt install libx11-6 libxrandr2 libxext6 libice6 libsm6 libfontconfig1`<br>Arch/Manjaro: `sudo pacman -S --needed libx11 libxrandr libxext libice libsm fontconfig` |
| `Cannot open X display` | Wayland session without XWayland: enable it, or log in to the X11 session. |
| Server not found | Allow mDNS, UDP 5353 (Fedora: `sudo firewall-cmd --permanent --add-service=mdns && sudo firewall-cmd --reload`, Ubuntu: `sudo ufw allow 5353/udp`), or start with `--server <server-ip>`. |
| KDE: wallpaper disappears after a click on the desktop | Run `install.sh` again (installs the KWin script, Plasma 6). |
| GNOME: wallpaper not behind windows | `install.sh --gnome-extension`, then log out and back in. |
| Other desktops: wallpaper above windows or not visible | Start with `--placement below`. |
| Black or garbled wallpaper | Start with `--software`. |
| Doesn't pause during a game | Native Wayland games aren't detected (XWayland ones, like most Steam/Proton games, are). |
| Out of sync | `timedatectl` must show *System clock synchronized: yes*. |
| Video layers missing | Not supported on Linux yet. |

Which session am I in? `echo $XDG_SESSION_TYPE` (`wayland` / `x11`), `echo $XDG_CURRENT_DESKTOP`, and on KDE
`plasmashell --version`.

**Logs:** the autostarted client logs nowhere. Stop it and run it in a terminal:

```bash
pkill -x wabibabusy-clie
wabibabusy-client --verbose --log-dir ~/wabibabusy-logs
```
