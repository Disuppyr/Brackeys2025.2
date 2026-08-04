---
name: webgl-game-reconstruction
description: Rebuild a playable Unity game from a decompiled/ripped WebGL build (AssetRipper "ExportedProject" output) where the C# was lost. Use when the user points at a ripped Unity project, a game folder whose scripts are AssetRipper stub comments, an "ExportedProject" directory, or asks to repair/reconstruct/recover a game from a web build. Covers the specific traps that make these exports silently unbuildable.
---

# Reconstructing a game from a ripped WebGL build

An AssetRipper export of a WebGL build is **not** a working project. Assets, scenes, and level
layout usually survive intact; the code is gone; and a handful of `ProjectSettings` fields are
zeroed in ways that crash Unity's build pipeline with no useful error. Every trap below was hit
on a real reconstruction — expect all of them.

Two rules that decide whether this goes well:

1. **Preserve `.meta` GUIDs.** They are what still wires scenes to scripts and sprites. Rewriting
   a stub script *in place* makes the surviving scene rewire itself for free. Creating a new file
   instead means rebuilding every reference by hand.
2. **Verify in a built player, not by reading code.** Editor batch play-mode is unreliable here.
   A `-smoke` self-test in the real player plus screenshots catches an enormous class of bug that
   looks fine in source. Build this early; it pays for itself many times over.

---

## Phase 1 — Triage (do this before writing any code)

```bash
# Is the code actually gone? AssetRipper stubs are ~62 identical lines of comment.
head -20 Assets/Scripts/Assembly-CSharp/*.cs | grep -c "Dummy class"
wc -l Assets/Scripts/Assembly-CSharp/*.cs      # all identical length == all stubs

ls Assets/                                      # Scenes, Scripts, Sprite, Texture2D, AudioClip
ls Assets/Scripts/                              # Assembly-CSharp + decompiled package copies
cat ProjectSettings/ProjectVersion.txt          # install this exact editor version
cat Packages/manifest.json                       # note what is MISSING, not just present
cat ProjectSettings/EditorBuildSettings.asset    # scene list + load order
sed -n '1,40p' ProjectSettings/TagManager.asset  # tags + sorting layers = the type system
```

**Tags are the surviving type system.** Ripped games commonly reuse one script across several
object kinds, distinguished only by tag (e.g. one script on planets, collectibles, and keys).
Legacy tag names from an earlier prototype are normal — read them as data, not intent.

Check whether the matching editor is installed (`/c/Program Files/Unity/Hub/Editor/<version>/`).
If it is, you can compile, build, and run — do not proceed blind.

---

## Phase 2 — Make the project buildable

These are ordered by how hard they are to diagnose from the symptom. Fix them all up front.

### 2a. Zeroed ProjectSettings fields → native crashes

AssetRipper writes `0` for fields that did not exist when the original was built. Unity then
divides by them.

| Field | Symptom | Fix |
|---|---|---|
| `m_DefaultShaderChunkSizeInMB: 0` | **every** player build dies in `SubProgramBlobWriter::Flush` / `CompileShaderSubprograms`, native crash, no CS error | `16` |
| `webGLInitialMemorySize: 0` | WebGL link fails: `emcc: error: INITIAL_MEMORY must be larger than TOTAL_STACK, was 0` | `32` |
| `webGLMaximumMemorySize: 0` | same | `2048` |
| `webGLMemoryGrowthMode: 0` | same family | `2` (geometric) |

```bash
sed -i 's/m_DefaultShaderChunkSizeInMB: 0/m_DefaultShaderChunkSizeInMB: 16/' ProjectSettings/ProjectSettings.asset
grep -nE "webGL(Memory|Initial|Maximum)" ProjectSettings/ProjectSettings.asset   # fix any 0s
```

### 2b. `m_AlwaysIncludedShaders` bloat

The export dumps every built-in shader (~29 entries); some fail to compile. Trim to what the game
needs — for a 2D sprite game that is two:

```yaml
  m_AlwaysIncludedShaders:
  - {fileID: 10753, guid: 0000000000000000f000000000000000, type: 0}   # Sprites/Default
  - {fileID: 10770, guid: 0000000000000000f000000000000000, type: 0}   # UI/Default
```

### 2c. Missing packages vs. decompiled stub copies

The single most confusing failure: the export ships a **decompiled stub copy** of packages
(`Assets/Scripts/UnityEngine.UI/`, `Unity.TextMeshPro`, `Unity.Burst`, …) whose `.asmdef` collides
by name with the real package. Meanwhile the real package is often *absent* from the manifest.

```
Assembly with name 'UnityEngine.UI' already exists (Assets/Scripts/UnityEngine.UI/UnityEngine.UI.asmdef)
```

Fix: add the real package to `Packages/manifest.json` (`"com.unity.ugui": "1.0.0"`) and **move every
decompiled package folder out of `Assets/`** (do not delete — move to `_unused_decompiled_packages/`,
reversible and reviewable). Keep only `Assembly-CSharp`.

Verify they were stubs first — `grep -c "Dummy class"` on one of their files.

### 2d. Exported lighting data

`Assets/Scenes/<SceneName>/LightingData.asset` + `Settings.lighting` crash Enlighten during batch
builds. A 2D game bakes no lighting. Move them out and null the scene references:

```python
s = re.sub(r'(m_LightingDataAsset: )\{fileID: [-\d]+, guid: [a-f0-9]+, type: \d+\}', r'\1{fileID: 0}', s)
s = re.sub(r'(m_LightingSettings: )\{fileID: [-\d]+, guid: [a-f0-9]+, type: \d+\}', r'\1{fileID: 0}', s)
s = s.replace('m_GIWorkflowMode: 0', 'm_GIWorkflowMode: 1')
```

### 2e. Delete `Library/`

The shipped `Library/` is stale derived data with a corrupt shader cache. `rm -rf Library Temp obj`
and let Unity regenerate.

---

## Phase 3 — Recover the script architecture via GUIDs

**The highest-leverage step in the whole job.** Build the map from scene bindings to stub files:

```bash
# GUID -> stub filename
cd Assets/Scripts/Assembly-CSharp
for f in *.cs; do echo "$(grep -a '^guid:' "$f.meta" | awk '{print $2}')  $f"; done | sort

# then find which scene objects bind each GUID (see the scene parser below)
```

Class names survive even though bodies do not, and they tell you the original architecture.
Expect the mapping to be *misleading*: a script named `Hook.cs` may be unused while the hook
object actually binds `Flight.cs`. Trust the GUIDs, not the names.

**Rewrite each bound stub in place, keeping its `.meta`.** The scene then rewires itself with zero
manual work. Do not rename classes — the class name must still match the file for Unity to bind.

Unused stubs (from other prototypes sharing the project) can be left alone; empty classes are
harmless.

---

## Phase 4 — Accept that all serialized inspector data is gone

Stub scripts mean AssetRipper wrote **no serialized fields**. Every reference the original set in
the inspector — sprites, clips, targets, tunables — is absent. So:

- **Self-wire at runtime.** Find by tag (`GameObject.FindGameObjectWithTag`), by child name
  (`transform.Find("crash")`), and load art/audio by name from `Resources`.
- Give one script the job of **scene doctor**: on `Start`, add every component the export lost
  (camera rig, HUD controller, line renderers) and delete objects the design cut.
- Write defensively: `GetComponent<T>() ?? AddComponent<T>()` everywhere, because you cannot rely
  on anything existing.

### Sprites: move to `Resources` for name-based loading

```bash
mkdir -p Assets/Resources && mv Assets/Sprite Assets/Resources/Sprite && mv Assets/Sprite.meta Assets/Resources/Sprite.meta
```

Moving preserves GUIDs (metas move too), so existing scene references keep working *and*
`Resources.Load<Sprite>("Sprite/<name>")` becomes available. Sub-sprites are named
`<Sheet>_0`, `<Sheet>_1`, … in slice order — resolve which is which by reading each `.asset`'s
`m_Rect` and viewing the source PNG.

**Read the source PNGs.** Sprite dimensions and `m_PixelsToUnits` tell you real world sizes, which
you need for collider/geometry sanity (e.g. a 190px sprite at 100 PPU is 1.9 units wide, so a
`0.92 * scale` trigger sits *inside* the art).

### UI is the worst-hit area

Because ugui was a stub, **every `Image`, `Text`, `Button`, `CanvasScaler` lost all data** — no
sprites, no fonts, no scaler settings. What survives is the `RectTransform` layout, because those
are native types.

So: **rebuild UI from code**, using the recovered RectTransforms as the layout spec. Read them out
of the scene YAML and put them in your config file.

Traps, all encountered:

- **No font asset exists.** Use `Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf")` (2022+),
  falling back to `"Arial.ttf"`.
- **An overlay Canvas parented under the camera gets dragged around.** `ScreenSpaceOverlay` still
  inherits the parent transform, so a camera that follows the player hauls the whole HUD off
  screen. `transform.SetParent(null, false)` it.
- **World-space canvases**: converting one to `ScreenSpaceOverlay` (usually necessary for
  resolution independence) relocates *any world-space child* — sprites parented under canvas
  elements end up hundreds of units away. Find them and re-home them to the scene root.
- **`Image.Type.Sliced` on art with no 9-slice border renders nothing.** Use `Simple`, or a flat
  colour fill.
- **Off-screen "hidden" positions are meaningful.** A 500-wide element parked at `x = -250`,
  anchored left, is exactly one width off screen — that is a slide-in animation, not a bug.
- Sprites with **baked-in text** (a button whose art says "LAUNCH") cannot be relabelled; use a
  flat fill plus a real label.

---

## Phase 5 — Audio recovery (`.resS` is usually a real media file)

WebGL builds encode audio as **AAC**, and AssetRipper emits `.audioclip` (YAML) + `.resS` (data).
Unity rejects them: *"Unsupported file or audio format"*.

```bash
# Confirm what the .resS actually is
xxd -l 16 SomeClip.audioclip.resS       # "ftypmp42" => it IS a standalone MP4/AAC file
grep -aE "m_Offset|m_Size|m_CompressionFormat" SomeClip.audioclip
```

Two separate problems:
- `m_CompressionFormat: 7` is AAC — not importable.
- `m_Offset` still points into the *original combined bundle* (e.g. offset 282519 inside a
  10334-byte file), while `m_Size` correctly equals the split file's size.

**Fix: transcode to WAV.** ffmpeg if present; otherwise Windows' own AAC decoder via WinRT, which
needs nothing installed. Working recipe (the awkward parts are noted — they cost real time):

```powershell
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
                   $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, $type) {
    $t = $asTaskGeneric.MakeGenericMethod($type).Invoke($null, @($op)); $t.Wait(-1) | Out-Null; $t.Result
}
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]             | Out-Null
[Windows.Media.Transcoding.MediaTranscoder, Windows.Media, ContentType = WindowsRuntime] | Out-Null

$profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWav(
    [Windows.Media.MediaProperties.AudioEncodingQuality]::High)
$prep = Await ($transcoder.PrepareFileTranscodeAsync($inFile, $outFile, $profile)) `
              ([Windows.Media.Transcoding.PrepareTranscodeResult])
$prep.TranscodeAsync() | Out-Null      # do NOT try to await this
```

- `IAsyncActionWithProgress<T>` **cannot** be awaited from PowerShell here — `AsTask` needs a
  progress type with no loadable projection, and `.Status` is not surfaced on the RCW.
- So **poll the output file** instead: a WAV's RIFF size field (bytes 4..8) is only patched when the
  writer closes, so *non-zero size field = finished*. Without this you get truncated files that
  look fine by length.

Then: put WAVs in `Assets/Resources/Audio/`, move the dead `.audioclip` assets out of `Assets/`,
and re-point every `AudioSource.clip` at runtime (the scene's clip references died with the old
assets). Keep the extracted MP4s somewhere for reference.

---

## Phase 6 — Mine the scenes for level data

Scene YAML survives fully and is the design document. Parse it rather than reading it by hand.

```python
import re
raw = open(scene_path, encoding='utf-8', errors='replace').read()
docs = [(int(m.group(1)), int(m.group(2)), m.start())
        for m in re.finditer(r'^--- !u!(\d+) &(\d+).*$', raw, re.M)]
blocks = {}
for i, (cls, fid, start) in enumerate(docs):
    end = docs[i+1][2] if i+1 < len(docs) else len(raw)
    blocks[fid] = (cls, raw[start:end])
# class ids: 1 GameObject, 4 Transform, 224 RectTransform, 212 SpriteRenderer,
# 50 Rigidbody2D, 58 CircleCollider2D, 60 PolygonCollider2D, 61 BoxCollider2D,
# 114 MonoBehaviour, 82 AudioSource, 20 Camera, 223 Canvas
```

Extract per object: name, tag, layer, active, position/scale, sprite GUID, collider geometry,
`MonoBehaviour` script GUID, and the **parent chain** (`m_Father`) — parenting explains a lot of
apparent nonsense.

**Look for co-located objects.** Two objects at identical coordinates are usually an *overlay* and
the thing it covers (a breakable shell over a collectible), not duplicates. This reveals mechanics:
one uniform collectible prefab plus separate obstacle objects layered on top. Getting this wrong
badly misreads the level (it changed a sheep count from "20" to the correct 13).

Also recover: camera `orthographic size` (may differ wildly per scene), sorting layers, and
`m_BackGroundColor` (transparent black usually means a backdrop asset that no longer renders — you
may need to generate one).

---

## Phase 7 — Config-first tuning

Export **every** tunable to one JSON file the moment you write the first system:

- `Assets/Resources/config.json`, loaded with `Resources.Load<TextAsset>("config")` +
  `JsonUtility.FromJsonOverwrite`. Synchronous on **all** platforms including WebGL (unlike
  `StreamingAssets`, which needs `UnityWebRequest` there).
- Keep C# defaults on every field so a missing/malformed file warns and falls back.
- Mark provenance in comments: recovered-from-project vs. designer-stated vs. invented.

This turns every "make it a bit faster" request into a one-line edit and gives the user real
control without touching code.

---

## Phase 8 — Build and verify (set this up early)

```bash
UNITY="/c/Program Files/Unity/Hub/Editor/<version>/Editor/Unity.exe"
"$UNITY" -batchmode -quit -projectPath "<abs path>" -executeMethod Build.Windows -logFile build.log
grep -aE "error CS|build:|crash has been" build.log | sort -u
```

Hard-won build rules:

- **Never pass `-nographics`.** Enlighten needs a graphics device: *"GfxDevice renderer is null"*
  then a crash.
- **Run the build twice after adding a new `.cs` file.** The first run imports it but compiles
  against the previous assembly set, reporting `CS0246: type not found` for the new type while
  still claiming success.
- **Clean up after a killed run.** Orphaned `Unity.exe` processes plus `Temp/UnityLockfile` cause
  `HandleProjectAlreadyOpenInAnotherInstance`. Kill the processes, delete the lockfile.
- Build a **Windows standalone** for iteration even when the target is WebGL — it is far faster and
  runs the same game code. Build WebGL to confirm the real target.
- For WebGL, if the game uses right-click, post-process `index.html` in the build method to
  `preventDefault` on `contextmenu` (Unity regenerates that file every build, so patch the output,
  not a template).

### The `-smoke` self-test — the most valuable thing you will build

Editor batch play-mode tends to stall (`EditorApplication.update` does not pump reliably). Instead
put a self-test **in the game**, gated on a command-line flag:

```csharp
[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
static void Boot() {
    foreach (var a in System.Environment.GetCommandLineArgs())
        if (a == "-smoke") { /* spawn the test object */ }
}
```

Have it: hook `Application.logMessageReceived` to count errors; assert scene wiring and level
counts; drive the real systems (reflection for private members is fine); `ScreenCapture.CaptureScreenshot`
at key moments; write a pass/fail report to `Application.persistentDataPath`; `Application.Quit(nonZero)`
on failure. Run it and read the report + screenshots every iteration.

**Always look at the screenshots.** They caught a clipped HUD, an invisible orbit ring, an
off-screen planet, and a bar that started non-empty — none of which any assertion had flagged.

### Test-writing pitfalls that cost real time here

- **Don't sample across a legitimate state boundary.** Measuring velocity "during" a recall that
  includes the dock reports the dock's deliberate zeroing as a lurch.
- **Assert behaviour, not field presence.** Reading a field set in `Awake` "passed" for three
  objects whose animation never ran. Assert the observable state instead.
- **`transform.position` lies.** With `RigidbodyInterpolation2D.Interpolate` it is the interpolated
  visual pose; use `rb.position` for geometry checks.
- **Setting `transform.position` on a kinematic body gets undone** if the owner drives it with
  `MovePosition(rb.position + …)`. Set `rb.position` too.
- If a subset of instances misbehaves, suspect **arbitrary `Awake` order plus a silent early
  return** (`if (_x == null) return;`). Make such methods self-sufficient and lazily initialise.
- Watch for **invulnerability/cooldown windows** swallowing a test's second hit.

---

## Phase 9 — Deliverables

- **GDD** (write it first if the user has not): recovered values marked distinctly from
  designer-stated and invented ones. It is the spec you build against and the record of what was
  archaeology vs. guess.
- **README**: what was wrong and what fixed it, the config reference, build commands, and an
  explicit **verified / not verified** split. Never imply a browser build was play-tested if it
  was only compiled.
- **Nothing deleted** — everything pulled from `Assets/` sits in `_unused_*/`, reversible.
- Keep legacy names (scene names, tags) if GUID bindings depend on them; note the confusion in the
  README rather than breaking the wiring.

## Working with the user

Ask about scope, fail state, delivery/scoring, and platform **before** building systems — those
four answers change the architecture. Reference screenshots of the original are extremely high
value: they revealed a missing planet, non-uniform object sizes, and animation the rebuild lacked.
Ask for one if the user has a build or recording.

When a request implies a change to already-documented behaviour, update the GDD too, so the
document does not silently contradict the build.
