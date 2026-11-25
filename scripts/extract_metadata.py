from pathlib import Path
import pandas as pd
import wave
import subprocess
import shutil

ROOT = Path(__file__).resolve().parents[1]

FMA_METADATA = Path.home() / "Downloads/fma_metadata/tracks.csv"

# Charger les morceaux réellement présents dans notre index
references = pd.read_csv(ROOT / "data/reference_files.csv")

# Charger les métadonnées FMA
tracks = pd.read_csv(
    FMA_METADATA,
    header=[0, 1],
    index_col=0,
    low_memory=False
)

rows = []

for _, ref in references.iterrows():

    audio_path = Path(ref["file"])

    # Identifiant FMA extrait du nom du fichier
    fma_id = int(audio_path.stem)

    if fma_id not in tracks.index:
        raise ValueError(f"Morceau FMA absent : {fma_id}")

    track = tracks.loc[fma_id]

    # Durée réelle de l'extrait audio
    duration = 30.0

    ffprobe = shutil.which("ffprobe")

    if ffprobe:
        duration = float(subprocess.check_output([
            ffprobe,
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            str(audio_path)
        ], text=True).strip())

    rows.append({
        "song_id": int(ref["song_id"]),
        "title": track[("track", "title")],
        "artist": track[("artist", "name")],
        "duration_s": round(duration, 3),
        "file": str(Path("fma_small") / audio_path.parent.name / audio_path.name),
        "set": "reference",
        "source": "Free Music Archive",
        "licence": track[("track", "license")],
        "fma_id": fma_id,
        "genre": track[("track", "genre_top")]
    })

metadata = pd.DataFrame(rows)

assert len(metadata) == 100
assert metadata["song_id"].tolist() == list(range(1, 101))
assert metadata["fma_id"].is_unique

metadata.to_csv(
    ROOT / "data/metadata.csv",
    index=False,
    encoding="utf-8"
)

print(f"\n{len(metadata)} morceaux documentés.")

print("\nPremiers morceaux :")
print(metadata[["song_id", "fma_id", "title", "artist", "genre"]].head())

print("\nMorceau utilisé pour les tests au microphone :")
print(metadata.loc[metadata["song_id"] == 19].to_string(index=False))

print("\nRépartition des genres :")
print(metadata["genre"].value_counts())

print("\nMétadonnées enregistrées avec succès.")