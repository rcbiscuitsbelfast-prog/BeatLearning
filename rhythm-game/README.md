# Rhythm Game

A Guitar Hero-style rhythm game that uses OSU beatmaps, integrated with BeatLearning for automatic beatmap generation from audio files.

## Features

- **4-Lane Gameplay**: D, F, J, K key controls
- **OSU Beatmap Support**: Compatible with standard OSU beatmap files
- **BeatLearning Integration**: Generate beatmaps automatically from MP3 files
- **Web Deployment**: Play directly in browser via GitHub Pages
- **Cross-Platform**: Windows, Linux, macOS, and HTML5 builds
- **Audio Synchronization**: Precise timing with MP3 playback
- **Scoring System**: Perfect, Great, Good accuracy ratings with combo tracking

## Quick Start

### Prerequisites

- Godot 4.2.1 or later (for local development)
- MP3 audio files for songs
- OSU beatmap files (.osu) for note patterns

### Setup

1. **Clone this repository** (or the main BeatLearning repository containing this project)
2. **Add audio files** to `src/assets/audio/`
   - Place MP3 files in this directory
3. **Add beatmap files** to `src/assets/beatmaps/`
   - Use the BeatLearning repository to generate .osu files from your MP3s
   - Or create/download existing OSU beatmaps
4. **Run the game**
   - Open `project.godot` in Godot editor
   - Press F5 to run, or export for your platform

### Using BeatLearning

1. **Generate Beatmaps**:
   ```bash
   cd ../beatlearning  # Navigate to BeatLearning directory
   python generate_beatmap.py your_song.mp3
   ```

2. **Move Files**:
   - Copy `your_song.mp3` to `rhythm-game/src/assets/audio/`
   - Copy generated `your_song.osu` to `rhythm-game/src/assets/beatmaps/`

3. **Update Beatmap**:
   - Open the .osu file and verify `AudioFilename:` matches your MP3 filename

## Controls

| Lane | Key | Color |
|------|-----|-------|
| Lane 0 | D | Red |
| Lane 1 | F | Blue |
| Lane 2 | J | Green |
| Lane 3 | K | Yellow |

- **ESC**: Pause/Resume game or return to menu
- **Enter**: Start game (from menu)
- **Mouse**: Navigate menus

## Game Mechanics

### Timing Windows
- **Perfect**: ±50ms
- **Great**: ±100ms
- **Good**: ±150ms
- **Miss**: Outside timing window

### Scoring
- **Perfect**: 300 points
- **Great**: 200 points
- **Good**: 100 points
- **Combo Bonus**: +10 points per combo level

### Note Types
- **Tap Notes**: Single arrows, hit when in target zone
- **Hold Notes**: Extended arrows with start and end timing
- **Empty Notes**: Visual only (BeatLearning feature)

## File Structure

```
rhythm-game/
├── project.godot                    # Godot project configuration
├── src/
│   ├── scenes/                      # Game scenes
│   │   ├── main.tscn               # Main menu scene
│   │   ├── gameplay.tscn           # Gameplay scene
│   │   └── menu.tscn               # Song selection menu
│   ├── scripts/                     # Game logic
│   │   ├── main.gd                 # Main game controller
│   │   ├── gameplay_manager.gd     # Core gameplay logic
│   │   ├── note.gd                 # Individual note behavior
│   │   ├── lane.gd                 # Lane management
│   │   ├── osu_parser.gd           # OSU beatmap parser
│   │   └── audio_manager.gd        # Audio synchronization
│   ├── assets/
│   │   ├── audio/                  # MP3 audio files
│   │   ├── beatmaps/               # .osu beatmap files
│   │   └── textures/               # Visual assets
│   └── ui/                         # UI components
├── .github/workflows/
│   └── build.yml                   # GitHub Actions for builds
└── export_presets.cfg              # Export settings
```

## Development

### Running Locally
1. Open `project.godot` in Godot 4.2.1
2. Navigate to the `rhythm-game` directory
3. Press F5 to run the game
4. Test with the included sample beatmap (requires MP3 file)

### Testing Workflow
1. Add test audio files to `src/assets/audio/`
2. Create or generate corresponding .osu files
3. Test gameplay in Godot editor
4. Export builds using the export presets

### Customization
- **Visual Assets**: Replace placeholder sprites in `src/assets/textures/`
- **Timing**: Adjust `NOTE_TRAVEL_TIME_MS` and `HIT_WINDOW_MS` in `gameplay_manager.gd`
- **Difficulty**: Modify scoring values and timing windows
- **Lanes**: Adjust lane positions and colors in `lane.gd`

## Deployment

### Automated Builds
The project includes GitHub Actions for automated deployment:

- **Trigger**: Push to main branch
- **Platforms**: HTML5, Windows, Linux, macOS
- **GitHub Pages**: Web deployment to `gh-pages` branch
- **Releases**: Automatic release creation with build artifacts

### Manual Export
1. Open project in Godot editor
2. Go to Project → Export
3. Select desired preset (HTML5, Windows, etc.)
4. Click Export Project

## BeatLearning Integration

This rhythm game is designed to work seamlessly with the BeatLearning system:

1. **Audio Analysis**: BeatLearning analyzes MP3 files and generates beat timing data
2. **Beatmap Generation**: Creates OSU-compatible .osu files with hit patterns
3. **Track Layouts**: Supports 1, 2, or 4 lane configurations
4. **AI-Powered**: Uses BEaRT model for intelligent rhythm detection

### Generate Custom Beatmaps
```python
from beatlearning import BeatmapGenerator

# Create beatmap from MP3
generator = BeatmapGenerator()
beatmap = generator.generate_from_audio("your_song.mp3", lanes=4)
beatmap.save_to_osu("your_song.osu")
```

## Troubleshooting

### Common Issues

**Audio not playing**:
- Verify MP3 files are in `src/assets/audio/`
- Check that `AudioFilename` in .osu files matches MP3 filename
- Ensure audio files are compatible (MP3, 44.1kHz recommended)

**Notes not appearing**:
- Check .osu file format and syntax
- Verify X coordinates correspond to lanes (64, 192, 320, 448)
- Ensure beatmap file is in the correct directory

**Timing issues**:
- Adjust audio offset in-game settings
- Check audio file quality and format
- Verify system audio latency

**Build errors**:
- Ensure Godot 4.2.1 is installed
- Check export template installation
- Verify file paths and permissions

### Performance Optimization

- **Web**: Keep songs under 3 minutes for faster loading
- **Mobile**: Test on target devices for touch input
- **Audio**: Use compressed audio formats for smaller builds

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is part of the BeatLearning system. See the main repository for license information.

## Acknowledgments

- **BeatLearning**: AI-powered beatmap generation system
- **OSU**: Rhythm game beatmap format
- **Godot Engine**: Cross-platform game engine
- **GitHub Actions**: Automated build and deployment

## Support

For issues and questions:
- Check the troubleshooting section
- Review the BeatLearning documentation
- Create an issue in the repository

Enjoy playing your custom rhythm games with BeatLearning-generated beatmaps! 🎵🎮