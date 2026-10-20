# Enhanced sawn-off blast

Owner source: explosive_shotgun_ear_ringing.wav, copied unchanged into source/.
Generated asset: sawn_off_deep_blast.wav (4.2s, mono, 44.1 kHz PCM16).
Rebuild from the project root: python tools/audio/deepen_sawn_off.py (NumPy).

Processing removes inaudible subsonic energy below roughly 28 Hz, emphasizes
bass/body, adds a short descending low thump and low-frequency early reflections,
and soft-limits the opening impact. Processing is full strength through 0.55s and
crossfades back to the original by 0.85s. Every sample after 0.85s is identical to
the owner's source. The source file is never overwritten.

Measured audible bass (35–180 Hz) in the first 400ms increases by 2.78 dB. Asset
peak is -0.92 dBFS with zero clipped samples. processing_checks.json records the
checks; regeneration asserts bass gain, tail identity and no clipping.

Only SAWN-OFF / CropDuster uses this asset. Its three existing pooled shot voices
share one preloaded stream, still at -5 dB on Effects. The pump uses its previous
sound. Native tools/check_sawn_off_audio.gd fires the actual weapon, verifies the
stream binding, fires both barrels with overlapping tails and captures unclipped
Effects-bus audio (single-shot peak 0.506; two-shot peak 0.926).
The in-game recording is docs/previews/sawn_off_deep_blast_ingame.wav.
