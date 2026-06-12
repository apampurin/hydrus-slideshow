# Hydrus Network Slideshow - KDE Plasma Widget

A KDE Plasma widget that displays a slideshow of images from Hydrus Network.

## Features

- 🖼️ Automatic slideshow of images from Hydrus Network
- 🔍 Search by tags
- 🔍 Search by local file domains
- ⚡ Thumbnail support for fast loading
- 🎨 Various image scaling modes
- ⏸️ Pause on mouse hover
- ◀️ ▶️ Previous/Next navigation
- 🔄 Random order
- 🎯 Smooth transitions between images

## Requirements

- KDE Plasma 5.20+
- Hydrus Network with API enabled
- Access to Hydrus Network API

## Installation

### 1. Copy the widget to the plasmoids folder

```bash
mkdir -p ~/.local/share/plasma/plasmoids/
cp -r kde-plasmoid-hydrus-slideshow ~/.local/share/plasma/plasmoids/org.kde.hydrus.slideshow
```

### 2. Restart Plasma Shell

```bash
kquitapp5 plasmashell
plasmashell &
```

Or simply reboot.

### 3. Add the widget to the desktop

- Right-click on the desktop
- Select "Add Widgets"
- Find "Hydrus Network Slideshow"
- Click on it to add

## Configuration

### General Settings

1. **Hydrus API URL** - your Hydrus API address (default: `http://127.0.0.1:45869`)
2. **Access Key** - your Hydrus API access key
3. **File Domain** - Local file domain name
4. **Search tags** - tags to search for (comma-separated, e.g.: `anime, cute, wallpaper`)
5. **Use thumbnails** - use thumbnails instead of full images (faster)

### Slideshow Settings

- **Change picture every** - image change interval (hours/minutes/seconds)
- **Randomize order** - random image order
- **Pause slideshow when cursor is over image** - pause on mouse hover
- **Click on image to open in external application** - open image on click
- **Image fill mode** - scaling mode (stretch, preserve aspect ratio, etc.)

## Obtaining a Hydrus API Key

1. Open Hydrus Network
2. Go to: `Services → Manage Services`
3. Find "Local Client API" and click on it
4. Click "Manage Client API Permissions"
5. Create a new access key
6. Copy the key and paste it into the widget settings

## Enabling CORS in Hydrus

If images do not load, make sure CORS is enabled:

1. In Hydrus, go to `Services → Manage Services`
2. Find "Local Client API"
3. In the settings, make sure CORS is allowed for your host

## Troubleshooting

### "No images found"

1. Check that the tags are entered correctly
2. Make sure Hydrus has images with those tags
3. Click the "Test Connection" button in settings

### "API not configured"

1. Make sure the API URL and access key are entered
2. Click "Test Connection" to verify

### Images not loading

1. Check that the Hydrus API is running
2. Make sure CORS is enabled in Hydrus
3. Check the API URL (default: `http://127.0.0.1:45869`)
4. Check the console logs (Ctrl+Alt+T and run `journalctl -f`)

## Development

### Project Structure

```
kde-plasmoid-hydrus-slideshow/
├── metadata.desktop      # Plasmoid metadata
├── metadata.json         # Plasmoid configuration
└── contents/
    ├── ui/
    │   ├── main.qml      # Main interface
    │   └── config.qml    # Configuration
    └── config/
        ├── ConfigGeneral.qml  # General settings
        └── ConfigHydrus.qml   # Hydrus settings
```

### Debugging

To view widget logs:

```bash
journalctl -f | grep -i hydrus
```

Or in the KDE console:

```bash
kquitapp5 plasmashell
plasmashell --debug &
```

## License

GPL-2.0-or-later

## Acknowledgements

Based on the standard `org.kde.plasma.mediaframe` plasmoid by Lars Pontoppidan.

## Author

Hydrus Network Slideshow Widget Contributors