# NetMonitor App Icon Requirements

## Design Theme
Network monitoring with modern macOS design language.

### Concept Ideas
1. **Radar/Sonar**: Concentric circles with sweeping beam
2. **Network Graph**: Nodes with connecting lines showing connectivity
3. **Signal Waves**: Radiating waves indicating monitoring activity
4. **Combined**: Network nodes with signal emanation

## Color Scheme
- **Primary Accent**: Cyan (#06B6D4) - matches app design system
- **Background**: Dark gradient or solid dark color
- **Highlights**: White or light cyan for contrast
- **Style**: Modern, professional, macOS native appearance

## Technical Requirements

### Required Icon Sizes
All icons must be PNG format with transparency:

| Size | Filename | Dimensions | Usage |
|------|----------|------------|-------|
| 16x16 @1x | icon_16x16.png | 16x16 px | Menu bar, small lists |
| 16x16 @2x | icon_16x16@2x.png | 32x32 px | Retina menu bar |
| 32x32 @1x | icon_32x32.png | 32x32 px | Finder list view |
| 32x32 @2x | icon_32x32@2x.png | 64x64 px | Retina Finder |
| 64x64 @1x | icon_64x64.png | 64x64 px | Sidebar icons |
| 64x64 @2x | icon_64x64@2x.png | 128x128 px | Retina sidebar |
| 128x128 @1x | icon_128x128.png | 128x128 px | Finder icon view |
| 128x128 @2x | icon_128x128@2x.png | 256x256 px | Retina Finder |
| 256x256 @1x | icon_256x256.png | 256x256 px | Dock |
| 256x256 @2x | icon_256x256@2x.png | 512x512 px | Retina Dock |
| 512x512 @1x | icon_512x512.png | 512x512 px | Large icons |
| 512x512 @2x | icon_512x512@2x.png | 1024x1024 px | Retina large |

### Design Guidelines
- **Rounded Corners**: macOS style (iOS-like squircle shape)
- **Shadow/Depth**: Subtle shadow to give dimensionality
- **Simplicity**: Icon should be recognizable at 16x16
- **Consistency**: Follow macOS Big Sur+ icon style
- **No Text**: Icon should work without text labels

## Icon Generation Options

### Option 1: Icon Composer Tools
- **AppIconBuilder** (appiconbuilder.com)
- **IconFly** (syniumsoftware.com)
- **ImageOptim** (imageoptim.com) for optimization

### Option 2: Design from Scratch
1. Create master icon at 1024x1024 in Sketch/Figma/Illustrator
2. Export all required sizes
3. Optimize with ImageOptim
4. Place in this directory

### Option 3: SF Symbols Based
Use SF Symbols as a starting point:
- `network` (concentric circles with node)
- `waveform.path.ecg` (signal waves)
- `wifi.router` (network device)
- Combine symbols and add custom styling

## Installation
Once icons are created, simply place the PNG files in this directory:
```
/Users/blake/Projects/NetMonitor/NetMonitor/Assets.xcassets/AppIcon.appiconset/
```

The Contents.json is already configured to reference these files.

## Verification
After adding icons:
1. Clean build folder (Cmd+Shift+K)
2. Build and run (Cmd+R)
3. Check Dock icon appears correctly
4. Check Finder icon at various sizes
5. Check menu bar icon (if applicable)

## Notes
- All files must be PNG format
- Transparency is supported and recommended
- File names are case-sensitive
- Retina (@2x) icons are exactly 2x the dimensions of @1x
