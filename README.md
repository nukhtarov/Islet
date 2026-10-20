<div align="center">

# 🏝️ Islet

**Text from your phone, right in your MacBook's notch.**

Like Dynamic Island on iPhone, but for the Mac.

![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)
![No Xcode](https://img.shields.io/badge/Xcode-not%20required-blue)
![Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)

**English** · [Русский](README.ru.md)

</div>

---

```
        ┌──────────────────────────────────────────────┐
        │                  ▀▀▀▀▀▀▀▀                     │  ← MacBook notch
        │      ╭──────────────────────────────╮        │
        │      │   Next slide: pricing        │        │  ← Islet
        │      ╰──────────────────────────────╯        │
        │                                              │
```

Type on your phone and the text slides out of the notch on your Mac as a clean
black "island". It tucks itself away again when you stop typing.

## ✨ Features

- **Live text**: appears as you type, no "send" button needed
- **No phone app**: runs in the browser, works on both iPhone and Android
- **QR code pairing**: point your camera and you're connected
- **Hidden from screen sharing**: you see the text, your Zoom / Meet audience doesn't\*
- **Dynamic Island–style animation**: slides out of the notch and back in smoothly
- **Auto-hide** after 7 seconds, font size from 14 to 24 pt
- **HTTP API**: send text from Shortcuts, scripts or OBS
- **Lightweight**: one process, zero dependencies, no cloud. Everything stays on your local Wi-Fi

<sub>\* On macOS 15+, some calling apps may ignore this flag, so test it beforehand (see below).</sub>

## 💡 Use cases

| | |
|---|---|
| 🎤 **Talks and presentations** | A prompter for your key points: you or a colleague sends cues from a phone, and the shared screen doesn't show them |
| 📹 **Streaming and recording** | Cues and script right under the camera, so your eyes stay on the lens |
| 🌍 **Translation** | Show output from a translator app on your phone |
| 🔔 **Notifications** | Build, deploy or timer status via the API |

## 🚀 Quick start

```bash
git clone https://github.com/nukhtarov/Islet.git
cd Islet
./build.sh
open Islet.app
```

You only need the **Command Line Tools** (`xcode-select --install`). Full Xcode is optional.

1. A 💬 icon appears in the menu bar. Click **Show QR code for phone…**
2. Scan the code with your phone's camera. Your Mac and phone must be on the same Wi-Fi network.
3. Start typing. The text is already in the notch.

> On first launch, macOS will ask about incoming connections / local network access. Allow it, or your phone won't be able to reach the Mac.

## ⚙️ Menu

| Item | What it does |
|---|---|
| `http://192.168.x.x:8765` | Address for your phone (click to copy) |
| Show QR code | QR code for quick pairing |
| Test text / Hide text | Check the display and hide it manually |
| Auto-hide | Hide the text after 7 seconds of silence |
| Hide from screen sharing | Keep Islet out of screen recordings and screen sharing |
| Remove menu bar icon | Remove 💬 entirely. To bring it back, open `Islet.app` again |
| Font size | 14 / 17 / 20 / 24 pt |

> The menu itself is currently in Russian.

## 🔌 API

The server listens on port `8765` on your local network.

```bash
# show text
curl -X POST --data 'Hello' http://localhost:8765/text

# same via GET, handy for links and Shortcuts
curl "http://localhost:8765/text?t=Hello"

# hide
curl http://localhost:8765/clear
```

**iPhone Shortcuts:** add a "Get Contents of URL" action, set the method to `POST`, and put your text in the request body.

## 🙈 Hiding from screen sharing

The Islet window is marked as excluded from screen capture (`NSWindow.sharingType = .none`).
Starting with macOS 15, Apple weakened this mechanism, and some ScreenCaptureKit-based apps
may still show the window. So:

- **test it before your talk** in the app you'll be presenting with;
- **the most reliable option** is to share a single window (e.g. your slides) instead of the whole screen.

## 🧱 How it works

```
Sources/Islet/
├── Notch.swift       window above the notch, the island's shape and animation
├── Server.swift      minimal HTTP server built on Network.framework
├── PhonePage.swift   phone page (HTML + JS)
└── main.swift        menu bar menu, QR code, settings
```

To develop in Xcode, run `open -a Xcode Package.swift`, then press ⌘R. Quit any built copy of Islet first, or the port will already be in use.

## 🗺️ Roadmap

- [ ] Teleprompter mode with auto-scrolling for long text
- [ ] A few lines of history
- [ ] English UI
- [ ] App icon and a signed release

---

<div align="center">
<sub>Made with ☕ and Swift</sub>
</div>
