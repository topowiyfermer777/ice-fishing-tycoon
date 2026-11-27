# Ice Fishing Tycoon — 3D Asset Manifest (`exports/glb/`)

Готовый пакет из **57 чистых glTF 2.0 (`.glb`) ассетов** (Y-up, пивот по центру внизу на `Y = 0.000`, масштаб `1 unit = 1 meter`, рост персонажей `~0.90–1.00 м`, все материалы Principled BSDF без служебных плоскостей и камер). **Все инструменты вынесены отдельно в `Tools/`** — персонажи экспортированы чистыми, без вшитых кирок и тесаков.

---

## 1. Characters (`Characters/` — 6 GLBs, Rigged & Animated, Tool-Free)

| File | Bones | Height | Animations (30 fps) | Notes |
|---|---:|---:|---|---|
| `Hero.glb` | 20 | `~1.00 m` | `Idle` (60f loop), `Idle_Carry` (60f loop), `Run` (18f loop), `Run_Carry` (18f loop), `Drop_Unload` (20f one-shot), `Mine_Strike` (20f one-shot), `Mine_Dual_Strike` (25f one-shot) | Clean character without tools; attach `Tools/Ice_Pickaxe.glb` to `hand.R` / `hand.L` in-engine |
| `Worker_Kenny.glb` | 20 | `~0.99 m` | Same 7 actions as `Hero.glb` | Orange Kenny parka worker without tools; attach `Tools/Ice_Pickaxe.glb` to `hand.R` / `hand.L` in-engine |
| `Chef.glb` | 21 | `~1.00 m` | `Idle` (60f loop), `Chop` (24f loop) | Clean character without cleaver; attach `Tools/Chef_Cleaver.glb` to `hand.R` in-engine |
| `Customer_Yellow.glb` | 20 | `~0.90 m` | `Idle` (60f loop), `Walk` (24f loop), `Wave` (60f one-shot), `Receive` (36f one-shot) | Evaporates in particle puff + drops cash after `Receive` (no walk-away anim needed) |
| `Customer_Teal.glb` | 20 | `~0.90 m` | Same 4 actions as `Customer_Yellow.glb` | Teal parka color variant |
| `Customer_White.glb` | 20 | `~0.90 m` | Same 4 actions as `Customer_Yellow.glb` | White parka color variant |

---

## 2. Food & Ice (`Food_And_Ice/` — 10 GLBs)
- `IceCube.glb`, `IceCube0.glb`, `IceCube1.glb`, `IceCube2.glb` — ice block damage stages
- `IceChunks.glb` — shattered ice debris
- `Tuna_v2.glb` — whole stylized tuna
- `Tuna_v2_Split.glb` — 5 cleanly capped fish parts (`Tuna_Part_01_Head` .. `Tuna_Part_05_Tail`) for chopping sequence
- `Tuna_Steak.glb` — primary served tuna steak (served bare, no bowl)
- `Tuna_Fillet.glb`, `Tuna_Slice.glb` — additional fish cut props

## 3. Stations, Cash & UI Pads (`Stations_And_UI/` — 13 GLBs)
- `ChefTable.glb` — chef cutting station with cutting board
- `Cauldron_Fire.glb` — soup cauldron over fire
- `Conveyor_Straight.glb`, `Conveyor_Turn.glb` — modular conveyor belt pieces
- `Plate_Wood.glb`, `Plate_Concrete.glb` — floor tiles / foundation pads
- `Cash_Bundle.glb`, `Cash_Stack_5.glb`, `Cash_Tower_20.glb` — cash drop & stack tiers
- `Icon_Pad_AddWorker.glb`, `Icon_Pad_Conveyor.glb`, `Icon_Pad_Expand.glb`, `Icon_Pad_LogDam.glb` — floor purchase/upgrade pads

## 4. Tools (`Tools/` — 2 GLBs, Separate Attachable Props)
- `Chef_Cleaver.glb` — attach to `Chef.glb` bone `hand.R`
- `Ice_Pickaxe.glb` — attach to `Hero.glb` / `Worker_Kenny.glb` bones `hand.R` & `hand.L`

### Exact Tool Socket Transforms (glTF 2.0 Y-Up, Bone-Local Space)
Attach the standalone tool GLB root directly as a child of the target bone node (`hand.R` / `hand.L`) using these exact transforms (measured directly from glTF export):

| Character | Tool GLB | Parent Bone | Position `[x, y, z]` | Quaternion `[x, y, z, w]` (glTF) | Euler XYZ (deg) | Scale |
|---|---|---|---|---|---|---|
| `Hero.glb` / `Worker_Kenny.glb` | `Tools/Ice_Pickaxe.glb` | `hand.R` | `[0.00000, 0.08908, 0.00000]` | `[0.50000, -0.50000, -0.50000, 0.50000]` | `[90.0, 0.0, -90.0]` | `[1.0, 1.0, 1.0]` |
| `Hero.glb` / `Worker_Kenny.glb` | `Tools/Ice_Pickaxe.glb` | `hand.L` | `[0.00000, 0.08908, 0.00000]` | `[0.50000, -0.50000, -0.50000, 0.50000]` | `[90.0, 0.0, -90.0]` | `[1.0, 1.0, 1.0]` |
| `Chef.glb` | `Tools/Chef_Cleaver.glb` | `hand.R` | `[0.00806, 0.05472, -0.01114]` | `[0.04387, 0.13219, 0.73359, 0.66517]` | `[14.71, 6.40, 96.43]` | `[0.88, 0.88, 0.88]` |

> **Tip:** Prefer applying `Quaternion [x, y, z, w]` directly (matches glTF/Three.js/Godot/Unity quaternion conventions with zero Euler-order ambiguity; in Unity negate X on position and X/W or use glTFast's native importer space).

## 5. Environment (`Environment/` — 16 GLBs)
- Cliffs: `Env_Cliff_Straight.glb`, `Env_Cliff_Corner.glb`, `Env_Cliff_InnerCorner.glb`, `Env_Cliff_Stepped.glb`, `Env_Cliff_Collapsed.glb`
- Pine trees: `Env_Pine_Small.glb`, `Env_Pine_Medium.glb`, `Env_Pine_Large.glb`
- Log dam / fences: `LogWall_Straight.glb`, `LogWall_Corner.glb`, `LogWall_U.glb`, `Log_Single_01.glb` .. `Log_Single_05.glb`

## 6. Winter Environment Props (`Environment_Props/` — 10 GLBs)
- `Env_BareBush.glb`, `Env_SnowGrass.glb`, `Env_RockCluster.glb`, `Env_SnowBoulder.glb`, `Env_IceCube_Decor.glb`, `Env_Campfire.glb`, `Env_LogPile.glb`, `Env_WoodCrate.glb`, `Env_WoodBarrel.glb`, `Env_SnowMound.glb`

---

## Re-exporting After Any Blender Edit
Run from the Blender workspace root:
```powershell
& "C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe" -b -P tools\export_all_glb.py
```
