# HiDPI scaling for external displays

Open **Settings → Displays → HiDPI Scaling**, or expand a monitor in the menu bar
panel’s **Displays** tab. For the external display you want
to configure, choose **Enable HiDPI** for a few common sizes or **Enable Flexible
Scaling** for a denser set of sizes. In the menu bar, select a profile before turning on the **HiDPI** switch.
Both profiles are off by default. Approve the system
administrator prompt, then reconnect the display. Restart the Mac if macOS
keeps the old mode list. To switch profiles, restore the previous override and
then enable the other profile.

After the profile is installed, the menu bar switch changes the active display
between 1× and 2× at its current refresh rate without administrator approval.
Turning it off keeps the profile installed. Turning it back on prefers the last
HiDPI size used with the switch in the current app session. Use Settings to
restore the previous system override or change the installed profile.

Vorssaint offers 2× HiDPI modes at the current refresh rate. It checks
CoreGraphics first, then checks for hidden 2× modes on supported configurations. The basic profile
adds the native size. Flexible Scaling also adds hidden sizes that match the
panel aspect ratio. If CoreGraphics reports no fixed rate, Vorssaint only
offers modes with an unreported rate. Choose a size with the slider to preview it automatically. Changing the
resolution uses the current session and does not request administrator access.
Installing or restoring a system override still requires administrator approval. Confirm within 15 seconds to keep the
resolution for the current display session. Otherwise Vorssaint attempts to
restore the previous resolution if the display is still available.

When several refresh rates are available for the active resolution and
scaling factor, use **Refresh rate** to preview another one. The same
15-second confirmation applies. On supported built-in Apple silicon displays,
Vorssaint labels the identified adaptive mode **ProMotion**.

Use **Restore Previous Override** to undo the installation, even if the
display is disconnected. The original local plist is kept beside the installed
override and restored byte for byte. If there was no local plist, restoring
removes the Vorssaint override. If another tool has changed the installed file,
Vorssaint keeps the backup and refuses to replace that file. Reconnect the
display or restart after restoring.

The macOS override applies to the vendor/product ID pair. Vorssaint blocks
installation and mode changes while multiple displays share those IDs. If you
connect another unit of the same model later, macOS can load the same
override for it. Connecting through another port or adapter can also change
the display identity. Restore the model's existing override before opting in
under a new identity.

The app targets macOS 14 and later on Apple Silicon. Mode selection uses public CoreGraphics APIs where available. The hidden-mode
fallback uses private SkyLight APIs and can become unavailable after macOS updates. macOS's model override format is undocumented, and the
available resolutions depend on the OS, GPU, display and connection. For
example, a panel's native size at 2× may require a framebuffer larger than the
GPU or WindowServer exposes. Mirrored displays are excluded from mode changes.
Use a directly connected display for troubleshooting.

The interaction is based on the [BetterDisplay public scaling guide][guide].
The plist format and scale generation are based on [Crisp][crisp] and its
[MIT notice](CRISP-LICENSE.txt).

[guide]: https://github.com/waydabber/BetterDisplay/wiki/Fully-scalable-HiDPI-desktop
[crisp]: https://github.com/didriksg/Crisp/tree/13346ede7106ded6566a9bbd9d501d6ed2454f6f
