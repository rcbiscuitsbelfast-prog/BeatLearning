# Audio Assets for Rhythm Game

## Audio Files

This directory should contain MP3 audio files for the rhythm game.

## Required Audio Files

### Test Audio
- `test_song.mp3` - A simple test song with clear beat
  - Duration: ~17 seconds (to match the test beatmap)
  - Tempo: 120 BPM
  - Format: MP3
  - Quality: 128 kbps or higher

## Adding Your Own Songs

1. Place MP3 files in this directory
2. Create corresponding .osu beatmap files in `../beatmaps/`
3. Ensure the AudioFilename in the .osu file matches the MP3 filename
4. Test the song in the game

## Audio Guidelines

- **Format**: MP3 (recommended for web compatibility)
- **Duration**: Keep songs reasonable for testing (1-5 minutes)
- **Quality**: 128-320 kbps
- **Sample Rate**: 44.1 kHz
- **Bit Depth**: 16-bit
- **Channels**: Stereo preferred

## BeatLearning Integration

When using BeatLearning to generate beatmaps:
1. Generate .osu files from your MP3 audio
2. Place the original MP3 in this directory
3. Copy the generated .osu file to the beatmaps directory
4. Update the AudioFilename in the .osu file if needed

## Test Audio Generation

For testing purposes, you can create simple audio using:
- Audacity (free audio editor)
- Online tone generators
- Simple metronome apps
- BeatLearning's built-in audio processing tools

## File Organization

```
src/assets/audio/
├── test_song.mp3
├── your_song_1.mp3
├── your_song_2.mp3
└── ... (additional songs)
```

## Note for Implementation

Since we cannot generate actual MP3 files in this environment, you'll need to:
1. Create or obtain MP3 audio files
2. Place them in this directory
3. Ensure they match the filenames specified in the .osu beatmap files
4. Test the complete audio-visual synchronization

The audio loading system in `audio_manager.gd` is designed to handle MP3 files and synchronize them with the beatmap timing data.