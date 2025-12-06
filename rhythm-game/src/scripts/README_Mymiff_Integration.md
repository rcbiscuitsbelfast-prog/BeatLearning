# K-Pop Demon Hunter - BeatLearning Integration for Mymiff AARPG

A complete rhythm-based demon capture system that integrates BeatLearning AI with the Mymiff AARPG tutorial project.

## 🎯 Overview

This integration adds a K-Pop themed rhythm capture mechanic to Mymiff AARPG where:
- Enemy HP drops below 25% → Capture button appears
- Player presses capture → 30-second rhythm game starts
- 4-lane gameplay (D, F, J, K keys) with capture meter
- Success → Demon captured permanently, battle ends
- Failure → Enemy HP restored (30-70%), battle resumes

## 📁 Project Structure

```
Mymiff-aarpg-tutorial/
├── Capture/                           # NEW - Rhythm capture system
│   ├── Scripts/
│   │   ├── rhythm_core/              # Copied from BeatLearning rhythm game
│   │   │   ├── gameplay_manager.gd   # Core rhythm game logic
│   │   │   ├── audio_manager.gd      # Audio synchronization
│   │   │   ├── note.gd              # Note behavior
│   │   │   ├── lane.gd              # 4-lane system
│   │   │   └── visual_effects_manager.gd  # K-Pop effects
│   │   └── capture_mode.gd          # Main capture controller
│   ├── Scenes/
│   │   ├── capture_mode.tscn         # Capture UI scene
│   │   └── capture_ui.tscn           # Meter, timer, effects
│   └── Assets/
│       ├── audio/demons/             # Demon theme songs
│       └── beatmaps/                # Generated rhythm patterns
├── Demons/                           # NEW - Demon data system
│   ├── Scripts/
│   │   └── demon_data.gd            # Demon resource class
│   └── Resources/
│       └── [demon_id].tres           # Individual demon resources
└── [Existing Mymiff directories]     # All original content preserved
```

## 🎮 Core Components

### 1. DemonData Resource Class
Links Mymiff enemy stats with capture rhythm parameters:

```gdscript
# Enemy combat stats
base_hp: float = 80.0
attack_damage: float = 15.0
defense: float = 5.0
level: int = 5
xp_reward: int = 50

# Capture parameters
capture_difficulty: float = 0.3      # BeatLearning difficulty (0.0-1.0)
capture_threshold: float = 0.25      # HP % when capture available
capture_duration: float = 30.0      # Capture sequence duration

# BeatLearning integration
theme_song_path: String              # Path to MP3
beatmap_path: String                 # Path to JSON beatmap
desired_bpm: float = 128.0           # Target BPM for generation
```

### 2. CaptureGameplayManager
Specialized rhythm game manager for demon capture:

- **Capture Progress**: Fills based on hit accuracy (Perfect +3%, Great +2%, Good +1%)
- **30-Second Timer**: Counts down during capture sequence
- **Success/Failure**: Emits appropriate signals based on results
- **BeatLearning Integration**: Uses AI-generated beatmaps

### 3. Enemy Integration
Modifies existing Mymiff Enemy class:

```gdscript
# Add to enemy.gd
signal capture_available(enemy: Enemy)
var demon_data: DemonData
var capture_available: bool = false

# In _take_damage():
_check_capture_availability()  # NEW: Check if capture available

# NEW: Capture system functions
func attempt_capture() -> bool
func restore_health(percentage: float)
```

### 4. Battle UI Integration
Adds capture button to existing battle interface:

- **Hidden by default**: Appears when enemy HP < 25%
- **Pulsing animation**: K-Pop styled visual feedback
- **Smooth transitions**: Battle → Capture → Battle

## 🎵 BeatLearning Integration

### AI Beatmap Generation
Uses BeatLearning's transformer model to generate rhythm patterns:

```python
# generate_mymiff_demons.py
model.generate(
    audio_file="shadow_imp_theme.mp3",
    audio_start=0.0,
    audio_end=30.0,                # 30-second capture sequences
    use_tracks=["LEFT", "DOWN", "UP", "RIGHT"],  # 4 lanes
    difficulty=0.3,                # Demon's capture difficulty
    temperature=0.1,
    beams=[2, 2, 2, 2] * 2
)
```

### Demon Configuration
JSON-based demon definitions for batch generation:

```json
{
  "demons": [
    {
      "id": "shadow_imp",
      "display_name": "Shadow Imp",
      "type": "shadow",
      "base_hp": 80,
      "capture_difficulty": 0.3,
      "desired_bpm": 128,
      "note_density": "medium",
      "theme_color": "#8B00FF"
    }
  ]
}
```

### Beatmap Format
Godot-compatible JSON format:

```json
{
  "version": "1.0",
  "bpm": 128,
  "lanes": 4,
  "notes": [
    {"time": 0.5, "lane": 0, "type": "tap"},
    {"time": 1.0, "lane": 1, "type": "special"},
    {"time": 1.5, "lane": 2, "type": "tap"}
  ]
}
```

## 🚀 Implementation Steps

### Phase 1: Setup Integration ✅
1. ✅ Clone Mymiff AARPG project
2. ✅ Create Capture/ directory structure
3. ✅ Copy rhythm game scripts to rhythm_core/
4. ✅ Create DemonData.gd resource class
5. ✅ Create CaptureGameplayManager

### Phase 2: Enemy System Integration ✅
1. ✅ Modify Enemy.gd to add capture_available signal at 25% HP
2. ✅ Add capture button to battle UI with K-Pop pulsing animation
3. ✅ Create capture_mode.tscn with rhythm game integration
4. ✅ Add demon collection tracking to SaveManager

### Phase 3: BeatLearning Integration ✅
1. ✅ Create demon_config.json for batch beatmap generation
2. ✅ Set up BeatLearning AI generation tool
3. ✅ Generate test beatmap for shadow_imp
4. ✅ Create DemonData resources for all demons

### Phase 4: Testing & Polish 🔄
1. 🔄 Test complete flow: battle → capture → success/failure
2. 🔄 Add K-Pop neon visual effects and audio
3. 🔄 Optimize performance and validate timing
4. 🔄 Create demon collection UI

## 🎮 Gameplay Flow

### Normal Battle
```
Player fights enemy → Enemy HP decreases → Combat continues as normal
```

### Capture Available
```
Enemy HP ≤ 25% → "CAPTURE" button appears → Player can press to start capture
```

### Capture Sequence
```
1. Battle pauses → Capture mode loads
2. 30-second timer starts → Capture meter at 0%
3. Rhythm gameplay begins → Notes spawn based on beatmap
4. Player hits notes (D, F, J, K) → Capture meter fills
5. Success: Meter reaches 100% → Demon captured, battle ends
6. Failure: Timer expires → HP restored (30-70%), battle resumes
```

## 🎯 Scoring System

### Note Accuracy
- **Perfect** (±50ms): +3% capture meter, 100 points
- **Great** (±100ms): +2% capture meter, 50 points
- **Good** (±150ms): +1% capture meter, 25 points
- **Miss**: 0% meter, combo breaks

### HP Restoration (Failure)
Based on performance score (0.0-1.0):
```gdscript
restore_percentage = 0.3 + (1.0 - performance) * 0.4
# Range: 30% (terrible) to 70% (perfect)
```

## 🔧 Tools & Scripts

### generate_mymiff_demons.py
Batch beatmap generation tool:

```bash
# Generate all demons
python generate_mymiff_demons.py --config demon_config.json --output ../Mymiff-aarpg-tutorial/Capture/Assets/

# Generate specific demon
python generate_mymiff_demons.py --demon shadow_imp --skip-beatlearning
```

### Features:
- BeatLearning AI beatmap generation (when available)
- Fallback placeholder beatmaps
- DemonData resource file generation
- Batch processing support
- Error handling and validation

## 🎨 K-Pop Visual Style

### Color Palette
- **Primary**: Neon pink (#FF1493), Electric blue (#00FFFF), Purple (#9400D3)
- **Secondary**: Lime green (#32FF32), Yellow (#FFFF00), Orange (#FF6600)
- **Background**: Dark navy (#000033) with subtle grid pattern
- **UI Elements**: Semi-transparent black with neon borders

### Visual Effects
- Neon pulse effects synced with music rhythm
- Particle effects on successful hits
- Screen shake on perfect combos
- Color changes based on capture meter level
- K-Pop styled fonts and animations

## 📊 Demon Examples

### Shadow Imp (Easy)
- **HP**: 80, **Difficulty**: 0.3, **BPM**: 128
- **Color**: Purple (#8B00FF), **Density**: Medium
- **Capture**: Available at 20 HP, 30-second sequence

### Fire Dragon (Hard)
- **HP**: 200, **Difficulty**: 0.8, **BPM**: 140
- **Color**: Orange (#FF4500), **Density**: High
- **Capture**: Available at 50 HP, 30-second sequence

### Ice Queen (Medium)
- **HP**: 150, **Difficulty**: 0.6, **BPM**: 110
- **Color**: Cyan (#00CED1), **Density**: Medium-High
- **Capture**: Available at 38 HP, 30-second sequence

## 🔧 Integration with Existing Mymiff Systems

### SaveManager Extension
```gdscript
# Add to current_save dictionary
captured_demons = [],
total_demons_captured = 0,
demon_collection_unlocked = false

# New functions
add_captured_demon(demon_data: DemonData)
is_demon_captured(demon_id: String) -> bool
get_capture_statistics() -> Dictionary
```

### PlayerManager Integration
```gdscript
# Grant XP on successful capture
PlayerManager.reward_xp(demon.xp_reward)

# Use existing camera shake system
PlayerManager.shake_camera()
```

### Audio System
- Uses existing global_audio_manager.gd for sound effects
- Respects volume settings and audio preferences
- Integrates with Mymiff's audio bus system

## 🎮 Controls

### Battle Controls
- **Movement**: WASD
- **Attack**: Left mouse
- **Dodge**: Spacebar
- **Capture**: Button appears when available

### Rhythm Controls
- **Lane 0 (D)**: Leftmost lane
- **Lane 1 (F)**: Left-center lane
- **Lane 2 (J)**: Right-center lane
- **Lane 3 (K)**: Rightmost lane

## 🧪 Testing

### Test Cases
1. **Battle to Capture Transition**: Smooth flow without lag
2. **Capture Meter**: Fills correctly based on accuracy
3. **Timer**: Counts down accurately from 30 seconds
4. **Success Path**: Demon captured, added to collection, battle ends
5. **Failure Path**: HP restored properly, battle resumes
6. **Audio Sync**: Notes aligned with beatmap timing
7. **Visual Effects**: K-Pop styling consistent throughout

### Performance Targets
- 60 FPS during both battle and capture
- <100ms scene transition times
- <50ms audio latency for rhythm gameplay
- Memory usage <500MB total

## 🐛 Known Issues & Limitations

### Current Limitations
- BeatLearning model checkpoint may not be included
- Audio files need to be provided separately
- Some visual effects need polish for K-Pop styling
- Demon sprite animations need to be created

### Future Enhancements
- Multi-demon capture sequences
- Combo multiplier effects on capture meter
- Special rhythm abilities for player
- Demon collection gallery with stats
- Online leaderboards for capture scores

## 📝 Next Steps

1. **Add Audio Files**: Create or source MP3 theme songs for each demon
2. **Generate Beatmaps**: Run BeatLearning generation tool with audio files
3. **Create Sprite Animations**: Design capture/defeat animations for demons
4. **Polish Visual Effects**: Add K-Pop neon effects and particles
5. **Playtest**: Test complete integration with multiple demons
6. **Balance**: Adjust difficulty thresholds and scoring as needed

## 🎉 Result

This integration successfully combines:
- ✅ **Mymiff AARPG**: Complete 2D action RPG framework
- ✅ **BeatLearning AI**: Procedural rhythm generation
- ✅ **4-Lane Rhythm Game**: Guitar Hero-style gameplay
- ✅ **K-Pop Aesthetic**: Neon visuals and electronic beats
- ✅ **Demon Collection**: Persistent progress tracking
- ✅ **30-Second Sequences**: Fast-paced capture gameplay

The result is a unique gaming experience that preserves all original Mymiff functionality while adding an innovative rhythm-based capture mechanic with AI-generated content! 🎵👹✨