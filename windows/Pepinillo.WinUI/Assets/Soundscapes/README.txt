Pepinillo Windows — Soundscapes assets
======================================

DEVELOPMENT PLACEHOLDERS ONLY
These *.mp3 files are short (≈2.5s) synthetic soft-noise loops generated with
ffmpeg (anoisesrc). They are NOT licensed commercial recordings and MUST be
replaced with properly licensed looping audio before public Microsoft Store
release.

Catalog (must match AudioPlayerService.BuildCatalog):
  FREE
    rain.mp3, forest.mp3, ocean.mp3, cafe.mp3
  PREMIUM (Pepinillo+ / Everywhere)
    whitenoise.mp3, fireplace.mp3, deepspace.mp3

Playback
  WindowsMediaPlayerService loads ms-appx:///Assets/Soundscapes/{AudioFileName}
  with IsLoopingEnabled. Missing files set LastStatusMessage and never crash.

Packaging
  Pepinillo.WinUI.csproj includes Assets\Soundscapes\**\* as Content.

Regenerate placeholders (requires ffmpeg):
  ffmpeg -y -f lavfi -i "anoisesrc=color=pink:duration=2.5:sample_rate=44100:amplitude=0.08" \
    -c:a libmp3lame -q:a 6 rain.mp3
  (repeat with brown/white/filters for other tracks)
