#!/usr/bin/env python3
"""
BeatLearning Integration Tool for Mymiff AARPG Demon Capture System

This tool generates rhythm game beatmaps for demons using BeatLearning AI,
then converts them to Godot JSON format for integration with Mymiff AARPG.

Usage:
    python generate_mymiff_demons.py --config demon_config.json --output ../Mymiff-aarpg-tutorial/Capture/Assets/

Requirements:
    - BeatLearning AI model
    - MP3 audio files for each demon theme song
    - Python 3.8+
"""

import json
import os
import sys
import argparse
from pathlib import Path

# Add BeatLearning to path
try:
    sys.path.insert(0, '../beatlearning')
    from beatlearning.models import BEaRT
    from beatlearning.tokenizers import BEaRTTokenizer
    from beatlearning.configs import QuaverBEaRT
    import torch
    BEATLEARNING_AVAILABLE = True
except ImportError:
    print("Warning: BeatLearning not available. Will create placeholder beatmaps.")
    BEATLEARNING_AVAILABLE = False

# Configuration
DEFAULT_CONFIG = "demon_config.json"
DEFAULT_OUTPUT_DIR = "../Mymiff-aarpg-tutorial/Capture/Assets/"
CONVERTER_SCRIPT = "../convert_ibf_to_godot.py"

def load_model():
    """Load BeatLearning AI model"""
    if not BEATLEARNING_AVAILABLE:
        return None, None

    config = QuaverBEaRT()
    tokenizer = BEaRTTokenizer(config)
    model = BEaRT(tokenizer)

    # Look for model checkpoint
    checkpoint_path = "../models/quaver_beart_v1.pt"
    if not os.path.exists(checkpoint_path):
        print("Warning: Model checkpoint not found at", checkpoint_path)
        return None, None

    try:
        if torch.cuda.is_available():
            model.load(checkpoint_path)
            model.to("cuda:0")
            print("Loaded BeatLearning model on GPU")
        else:
            model.load(checkpoint_path, map_location=torch.device("cpu"))
            print("Loaded BeatLearning model on CPU")
    except Exception as e:
        print(f"Error loading BeatLearning model: {e}")
        return None, None

    return model, tokenizer

def create_placeholder_beatmap(demon_config, output_path):
    """Create a placeholder beatmap when BeatLearning is not available"""

    # Calculate note parameters based on difficulty
    difficulty = demon_config['capture_difficulty']
    duration = demon_config['capture_duration']
    bpm = demon_config['desired_bpm']

    # Note density based on difficulty
    note_density_map = {
        "low": 0.5,
        "medium": 1.0,
        "medium_high": 1.3,
        "high": 1.6,
        "very_high": 2.0
    }

    note_density = note_density_map.get(demon_config['note_density'], 1.0)

    # Generate notes
    notes = []
    seconds_per_beat = 60.0 / bpm
    total_beats = int(duration / seconds_per_beat)

    # Generate notes with varying density
    for beat in range(total_beats):
        time = beat * seconds_per_beat

        # Chance to spawn notes based on density
        if beat % max(1, int(2 / note_density)) == 0:
            # Random lane
            lane = beat % 4

            # Special notes based on frequency
            if demon_config['special_note_frequency'] > 0 and (beat % 8 == 0):
                note_type = "special"
            else:
                note_type = "tap"

            notes.append({
                "time": round(time, 3),
                "lane": lane,
                "type": note_type
            })

    # Create Godot JSON format beatmap
    beatmap = {
        "version": "1.0",
        "creator": "BeatLearning Placeholder Generator",
        "song_name": demon_config['display_name'] + " Theme",
        "difficulty": str(demon_config['capture_difficulty']),
        "bpm": bpm,
        "duration": duration,
        "lanes": 4,
        "notes": notes,
        "metadata": {
            "demon_id": demon_config['id'],
            "generated_by": "placeholder",
            "capture_difficulty": difficulty,
            "note_density": demon_config['note_density']
        }
    }

    # Save beatmap
    with open(output_path, 'w') as f:
        json.dump(beatmap, f, indent=2)

    print(f"Generated placeholder beatmap: {output_path} ({len(notes)} notes)")

def generate_beatmap_with_beatlearning(model, tokenizer, demon_config, audio_path, output_path):
    """Generate beatmap using BeatLearning AI"""

    try:
        print(f"Generating beatmap for {demon_config['display_name']} with BeatLearning...")

        # Calculate generation parameters
        difficulty = demon_config['capture_difficulty']
        duration = demon_config['capture_duration']

        # Generate beatmap with BeatLearning
        ibf = model.generate(
            audio_file=audio_path,
            audio_start=0.0,
            audio_end=duration,
            use_tracks=["LEFT", "DOWN", "UP", "RIGHT"],  # 4 lanes
            difficulty=difficulty,
            temperature=0.1,
            beams=[2, 2, 2, 2] * 2,
            random_seed=42
        )

        # Save IBF file
        ibf_path = output_path.replace('.json', '.ibf')
        ibf.save(ibf_path)
        print(f"Saved IBF: {ibf_path}")

        # Convert to Godot JSON format
        if os.path.exists(CONVERTER_SCRIPT):
            import subprocess
            result = subprocess.run([
                'python', CONVERTER_SCRIPT,
                ibf_path,
                output_path,
                '--lanes', '4'
            ], capture_output=True, text=True)

            if result.returncode == 0:
                print(f"Generated BeatLearning beatmap: {output_path}")
            else:
                print(f"Error converting beatmap: {result.stderr}")
                # Fallback to placeholder
                create_placeholder_beatmap(demon_config, output_path)
        else:
            print(f"Converter script not found: {CONVERTER_SCRIPT}")
            # Fallback to placeholder
            create_placeholder_beatmap(demon_config, output_path)

    except Exception as e:
        print(f"Error generating beatmap with BeatLearning: {e}")
        # Fallback to placeholder
        create_placeholder_beatmap(demon_config, output_path)

def load_demon_config(config_path):
    """Load demon configuration from JSON file"""
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading demon config: {e}")
        return None

def ensure_output_directories(output_dir):
    """Create necessary output directories"""
    directories = [
        "beatmaps",
        "audio/demons"
    ]

    for directory in directories:
        full_path = os.path.join(output_dir, directory)
        os.makedirs(full_path, exist_ok=True)
        print(f"Created directory: {full_path}")

def generate_demon_resources(demon_config, output_dir):
    """Generate DemonData resource files for Mymiff"""

    # Create DemonData script content
    demon_data_template = """
[gd_resource type="Resource" script_class="DemonData"]
script = ExtResource("res://Capture/Scripts/DemonData.gd")

[resource]
id = "{id}"
display_name = "{display_name}"
demon_type = "{type}"
base_hp = {base_hp}
attack_damage = {attack_damage}
defense = {defense}
level = {level}
xp_reward = {xp_reward}
capture_difficulty = {capture_difficulty}
capture_threshold = {capture_threshold}
capture_duration = {capture_duration}
can_be_captured = {can_be_captured}
theme_song_path = "{theme_song_path}"
beatmap_path = "{beatmap_path}"
desired_bpm = {desired_bpm}
note_density = "{note_density}"
special_note_frequency = {special_note_frequency}
theme_color = Color({theme_color})
secondary_color = Color({secondary_color})
capture_animation = "{capture_animation}"
defeat_animation = "{defeat_animation}"
description = "{description}"
capture_quote = "{capture_quote}"
defeat_quote = "{defeat_quote}"
abilities = [{abilities_list}]
drop_items = [{drop_items_list}]
enemy_scene_path = "{enemy_scene_path}"
"""

    # Generate resource file for each demon
    resources_dir = os.path.join(output_dir, "../Capture/Resources/Demons")
    os.makedirs(resources_dir, exist_ok=True)

    for demon in demon_config['demons']:
        # Convert color hex to RGB
        theme_color = demon['theme_color']
        if theme_color.startswith('#'):
            theme_color = theme_color[1:]

        # Format arrays
        abilities_list = ', '.join([f'"{ability}"' for ability in demon['abilities']])
        drop_items_list = ', '.join([f'"{item}"' for item in demon['drop_items']])

        # Escape quotes in text fields
        description = demon['description'].replace('"', '\\"')
        capture_quote = demon['capture_quote'].replace('"', '\\"')
        defeat_quote = demon['defeat_quote'].replace('"', '\\"')

        resource_content = demon_data_template.format(
            id=demon['id'],
            display_name=demon['display_name'],
            type=demon['type'],
            base_hp=demon['base_hp'],
            attack_damage=demon['attack_damage'],
            defense=demon['defense'],
            level=demon['level'],
            xp_reward=demon['xp_reward'],
            capture_difficulty=demon['capture_difficulty'],
            capture_threshold=demon['capture_threshold'],
            capture_duration=demon['capture_duration'],
            can_be_captured=str(demon['can_be_captured']).lower(),
            theme_song_path=demon['theme_song_path'],
            beatmap_path=demon['beatmap_path'],
            desired_bpm=demon['desired_bpm'],
            note_density=demon['note_density'],
            special_note_frequency=demon['special_note_frequency'],
            theme_color=theme_color,
            secondary_color=demon['secondary_color'],
            capture_animation=demon['capture_animation'],
            defeat_animation=demon['defeat_animation'],
            description=description,
            capture_quote=capture_quote,
            defeat_quote=defeat_quote,
            abilities_list=abilities_list,
            drop_items_list=drop_items_list,
            enemy_scene_path=demon['enemy_scene_path']
        )

        resource_path = os.path.join(resources_dir, f"{demon['id']}.tres")
        with open(resource_path, 'w') as f:
            f.write(resource_content)

        print(f"Generated resource: {resource_path}")

def main():
    parser = argparse.ArgumentParser(description='Generate beatmaps for Mymiff AARPG demon capture system')
    parser.add_argument('--config', default=DEFAULT_CONFIG, help='Demon configuration file')
    parser.add_argument('--output', default=DEFAULT_OUTPUT_DIR, help='Output directory')
    parser.add_argument('--demon', help='Generate beatmap for specific demon only')
    parser.add_argument('--skip-beatlearning', action='store_true', help='Skip BeatLearning generation, use placeholders')

    args = parser.parse_args()

    # Load configuration
    config = load_demon_config(args.config)
    if not config:
        print("Failed to load configuration")
        return 1

    # Ensure output directories exist
    ensure_output_directories(args.output)

    # Load BeatLearning model (unless skipped)
    model = None
    tokenizer = None
    if not args.skip_beatlearning:
        model, tokenizer = load_model()

    # Generate beatmaps
    demons_to_process = config['demons']
    if args.demon:
        demons_to_process = [d for d in demons_to_process if d['id'] == args.demon]
        if not demons_to_process:
            print(f"Demon '{args.demon}' not found in configuration")
            return 1

    print(f"Processing {len(demons_to_process)} demon(s)...")

    for demon in demons_to_process:
        print(f"\n🎵 Processing: {demon['display_name']}...")

        # Generate beatmap
        beatmap_filename = f"{demon['id']}.json"
        beatmap_path = os.path.join(args.output, "beatmaps", beatmap_filename)
        audio_path = os.path.join(args.output, "audio/demons", os.path.basename(demon['theme_song_path']))

        # Check if audio file exists
        if not os.path.exists(audio_path):
            print(f"Warning: Audio file not found: {audio_path}")
            # Continue anyway - beatmap generation can work without audio

        # Generate beatmap
        if model and tokenizer and BEATLEARNING_AVAILABLE:
            generate_beatmap_with_beatlearning(model, tokenizer, demon, audio_path, beatmap_path)
        else:
            create_placeholder_beatmap(demon, beatmap_path)

    # Generate DemonData resource files
    print(f"\n📄 Generating DemonData resources...")
    generate_demon_resources(config, args.output)

    print(f"\n✅ Complete! Generated beatmaps and resources for {len(demons_to_process)} demon(s)")
    print(f"Output directory: {args.output}")

    return 0

if __name__ == "__main__":
    sys.exit(main())