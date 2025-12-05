#!/usr/bin/env python3
"""
BeatLearning IBF to Godot JSON Converter

This script converts Intermediate Beatmap Format (IBF) files from BeatLearning
into Godot-friendly JSON format for the rhythm game.

Usage:
    python convert_ibf_to_godot.py input.ibf output.json [--lanes 4] [--style guitar-hero]
"""

import json
import argparse
import sys
import os
from pathlib import Path
import pandas as pd

try:
    from beatlearning.utils import IntermediateBeatmapFormat
    BEATLEARNING_AVAILABLE = True
except ImportError:
    print("Warning: BeatLearning not available. Using simplified IBF parser.")
    BEATLEARNING_AVAILABLE = False


class IBFConverter:
    def __init__(self, lanes=4, style="guitar-hero"):
        self.lanes = lanes
        self.style = style

        # Lane mappings for different styles
        self.lane_mappings = {
            "guitar-hero": {
                4: ["LEFT", "DOWN", "UP", "RIGHT"],  # Standard Guitar Hero
                2: ["LEFT", "RIGHT"],                # Dual lane
                1: ["CENTER"]                        # Single lane
            },
            "dance": {
                4: ["LEFT", "DOWN", "UP", "RIGHT"],   # DDR style
                2: ["LEFT", "RIGHT"],                # Two panel
                1: ["CENTER"]                        # Single panel
            },
            "drums": {
                4: ["KICK", "SNARE", "HI-HAT", "CRASH"],  # Drum layout
                2: ["KICK", "SNARE"],
                1: ["KICK"]
            }
        }

    def load_ibf(self, ibf_path):
        """Load IBF file using BeatLearning or fallback parser"""
        if BEATLEARNING_AVAILABLE:
            return self._load_with_beatlearning(ibf_path)
        else:
            return self._load_fallback(ibf_path)

    def _load_with_beatlearning(self, ibf_path):
        """Load IBF using BeatLearning library"""
        ibf = IntermediateBeatmapFormat(ibf_path)

        metadata = {
            "audio": ibf.meta.get("audio", ""),
            "difficulty": ibf.meta.get("difficulty", "Normal"),
            "bpm": ibf.meta.get("bpm", 120.0),
            "duration": ibf.meta.get("duration", 0),
            "tracks": ibf.meta.get("tracks", self._get_default_tracks()),
            "beatlearning_version": "2.0"
        }

        return {
            "metadata": metadata,
            "data": ibf.data
        }

    def _load_fallback(self, ibf_path):
        """Fallback IBF parser when BeatLearning is not available"""
        try:
            # Try to parse as JSON first (newer format)
            with open(ibf_path, 'r') as f:
                ibf_data = json.load(f)
                return ibf_data
        except:
            # Try to parse as CSV with metadata
            try:
                data = pd.read_csv(ibf_path)
                metadata = self._extract_metadata_from_path(ibf_path)
                return {
                    "metadata": metadata,
                    "data": data
                }
            except Exception as e:
                raise ValueError(f"Failed to parse IBF file: {e}")

    def _extract_metadata_from_path(self, ibf_path):
        """Extract basic metadata from filename when not available in file"""
        path = Path(ibf_path)
        name = path.stem

        return {
            "audio": name + ".mp3",
            "difficulty": "Normal",
            "bpm": 120.0,
            "duration": 0,
            "tracks": self._get_default_tracks(),
            "beatlearning_version": "unknown"
        }

    def _get_default_tracks(self):
        """Get default track names for current lane configuration"""
        style_mapping = self.lane_mappings.get(self.style, self.lane_mappings["guitar-hero"])
        return style_mapping.get(self.lanes, ["LEFT", "DOWN", "UP", "RIGHT"][:self.lanes])

    def convert_to_godot(self, ibf_data, output_path):
        """Convert IBF data to Godot JSON format"""
        metadata = ibf_data["metadata"]
        df = ibf_data["data"]

        # Extract metadata
        godot_beatmap = {
            "metadata": {
                "title": metadata.get("title", "Unknown Song"),
                "artist": metadata.get("artist", "Unknown Artist"),
                "difficulty": metadata.get("difficulty", "Normal"),
                "audio_filename": metadata.get("audio", ""),
                "bpm": metadata.get("bpm", 120.0),
                "duration": metadata.get("duration", 0),
                "lanes": self.lanes,
                "style": self.style,
                "beatlearning_version": metadata.get("beatlearning_version", "unknown"),
                "generated_by": "BeatLearning"
            },
            "timing_points": [],
            "hit_objects": []
        }

        # Get track names from IBF metadata or use defaults
        tracks = metadata.get("tracks", self._get_default_tracks())

        # Convert each row to note events
        for _, row in df.iterrows():
            time_ms = row.get("TIME", 0)

            # Check each track for notes
            for i, track in enumerate(tracks[:self.lanes]):
                if track in row:
                    note_value = row[track]

                    if note_value == 1:  # Hit/tap event
                        godot_beatmap["hit_objects"].append({
                            "time": int(time_ms),
                            "lane": i,  # 0-3 for 4 lanes
                            "type": "tap",
                            "duration": 0
                        })
                    elif note_value == 2:  # Hold start/continue
                        # Calculate hold duration by looking ahead
                        hold_duration = self._calculate_hold_duration(df, i, time_ms)
                        godot_beatmap["hit_objects"].append({
                            "time": int(time_ms),
                            "lane": i,
                            "type": "hold",
                            "duration": int(hold_duration)
                        })
                    elif note_value == 3:  # Special note type
                        godot_beatmap["hit_objects"].append({
                            "time": int(time_ms),
                            "lane": i,
                            "type": "special",
                            "duration": 0
                        })

        # Sort hit objects by time
        godot_beatmap["hit_objects"].sort(key=lambda x: x["time"])

        # Generate timing points (simplified)
        bpm = metadata.get("bpm", 120.0)
        beat_length_ms = 60000.0 / bpm

        godot_beatmap["timing_points"] = [
            {
                "time": 0,
                "beat_length": beat_length_ms,
                "meter": 4,
                "sample_set": "normal",
                "sample_index": 0,
                "volume": 100,
                "uninherited": True,
                "effects": 0
            }
        ]

        # Write output file
        with open(output_path, 'w') as f:
            json.dump(godot_beatmap, f, indent=2)

        return godot_beatmap

    def _calculate_hold_duration(self, df, lane, start_time):
        """Calculate duration of hold note by looking ahead in the data"""
        future_rows = df[df["TIME"] > start_time]

        for _, future_row in future_rows.iterrows():
            future_time = future_row.get("TIME", 0)
            track_name = self._get_default_tracks()[lane] if lane < len(self._get_default_tracks()) else f"LANE_{lane}"

            if track_name in future_row and future_row[track_name] != 2:
                # Hold ended before this time
                return future_time - start_time

        # Hold continues to end of song
        return 1000  # Default 1 second if we can't determine end

    def generate_beatmap_for_audio(self, audio_path, output_path, difficulty=0.6, bpm=None):
        """Generate a beatmap for an audio file using BeatLearning"""
        if not BEATLEARNING_AVAILABLE:
            print("Error: BeatLearning not available. Cannot generate beatmaps.")
            return False

        try:
            # This would call the actual BeatLearning model
            # For now, we'll create a simple pattern
            print(f"Generating beatmap for {audio_path}...")

            # Simple pattern generation (placeholder for actual BeatLearning integration)
            beatmap = {
                "metadata": {
                    "title": Path(audio_path).stem,
                    "artist": "Generated",
                    "difficulty": "Normal" if difficulty < 0.7 else "Hard",
                    "audio_filename": Path(audio_path).name,
                    "bpm": bpm or 120.0,
                    "duration": 0,
                    "lanes": self.lanes,
                    "style": self.style,
                    "beatlearning_version": "2.0",
                    "generated_by": "BeatLearning AI"
                },
                "timing_points": [{
                    "time": 0,
                    "beat_length": 60000.0 / (bpm or 120.0),
                    "meter": 4,
                    "sample_set": "normal",
                    "sample_index": 0,
                    "volume": 100,
                    "uninherited": True,
                    "effects": 0
                }],
                "hit_objects": self._generate_pattern(difficulty, bpm or 120.0)
            }

            with open(output_path, 'w') as f:
                json.dump(beatmap, f, indent=2)

            print(f"Generated beatmap: {output_path}")
            return True

        except Exception as e:
            print(f"Error generating beatmap: {e}")
            return False

    def _generate_pattern(self, difficulty, bpm, duration=30):
        """Generate a simple pattern for demonstration"""
        notes = []
        beat_duration = 60000.0 / bpm

        # Generate pattern based on difficulty
        note_density = 2 + int(difficulty * 3)  # 2-5 notes per beat

        for beat in range(int(duration * bpm / 60)):
            beat_time = beat * beat_duration

            # Add notes with some randomness
            for sub_beat in range(note_density):
                if sub_beat == 0 or (difficulty > 0.5 and sub_beat % 2 == 0):
                    lane = (beat + sub_beat) % self.lanes
                    notes.append({
                        "time": int(beat_time + sub_beat * beat_duration / note_density),
                        "lane": lane,
                        "type": "tap",
                        "duration": 0
                    })

        return notes


def main():
    parser = argparse.ArgumentParser(description="Convert BeatLearning IBF files to Godot JSON format")
    parser.add_argument("input", help="Input IBF file or audio file")
    parser.add_argument("output", help="Output JSON file")
    parser.add_argument("--lanes", type=int, default=4, choices=[1, 2, 4],
                       help="Number of lanes (1, 2, or 4)")
    parser.add_argument("--style", default="guitar-hero",
                       choices=["guitar-hero", "dance", "drums"],
                       help="Game style")
    parser.add_argument("--difficulty", type=float, default=0.6,
                       help="Difficulty level (0.0-1.0)")
    parser.add_argument("--bpm", type=float, help="BPM for generated beatmaps")
    parser.add_argument("--generate", action="store_true",
                       help="Generate beatmap from audio file")

    args = parser.parse_args()

    # Validate inputs
    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found")
        return 1

    # Create converter
    converter = IBFConverter(lanes=args.lanes, style=args.style)

    try:
        if args.generate:
            # Generate beatmap from audio
            success = converter.generate_beatmap_for_audio(
                args.input, args.output, args.difficulty, args.bpm
            )
            if not success:
                return 1
        else:
            # Convert existing IBF file
            ibf_data = converter.load_ibf(args.input)
            godot_beatmap = converter.convert_to_godot(ibf_data, args.output)

            print(f"✅ Successfully converted {args.input} to {args.output}")
            print(f"📵 Notes: {len(godot_beatmap['hit_objects'])}")
            print(f"🎵 Duration: {godot_beatmap['metadata']['duration']}ms")
            print(f"🎸 Style: {args.style} with {args.lanes} lanes")

        return 0

    except Exception as e:
        print(f"Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())