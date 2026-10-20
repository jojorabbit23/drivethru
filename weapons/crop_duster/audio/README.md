# Selected sawn-off sound pack

Current owner-selected samples, copied unchanged from the split pack:
- shotgun_sound_04.wav: firing (three pooled voices, -8 dB, Effects).
- shotgun_sound_13.wav: each shell seating, at 1.9 s / 2.4 s in the reload.
- shotgun_sound_14.wav: opening/cocking the action to begin a reload.

The two reload voices use -11 dB on Effects, allowing shell tails to overlap. Only shells actually inserted play the loading sound. Holstering/death cancels reload voices; full guns and empty reserves cannot start a reload. Closing the action retains its existing mechanical click. The pump shotgun is unchanged. Native capture measured a 0.796 peak during the two-shot/reload check, below clipping.

Run native tools/check_sawn_off_audio.gd to verify actual sound bindings, two shots with overlapping tails, cocking, both insertions, top-up and cancellation, and record the Effects bus into docs/previews/sawn_off_selected_audio_ingame.wav.

## Previous enhanced blast (retained, no longer the selected firing sound)

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

The older in-game recording is retained as docs/previews/sawn_off_deep_blast_ingame.wav for reference. Current playback and verification use the selected clips described above.
