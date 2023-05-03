# [L4D/2] Dynamic Tank Mobs
This is a SourceMod Plugin that spawns small mobs while the Tank is in the game. This was originally made for PvP game modes such as Versus. You might have to tweak some Director intensity CVars if you want to use it in Co-op.

# CVars
- `z_tank_mob_spawn_min_size` (set to `5` by default)
- `z_tank_mob_spawn_max_size` (set to `10` by default)
- `z_tank_mob_spawn_min_interval` (set to `10.0` by default)
- `z_tank_mob_spawn_max_interval` (set to `20.0` by default)

# Example VScript Code
```
DirectorOptions <-
{
	ShouldAllowMobsWithTank = true
	MobMinSize = 10
	MobSpawnMinTime = 10.0
	MobSpawnMaxTime = 20.0
}
```

# Requirements
- [SourceMod 1.11+](https://www.sourcemod.net/downloads.php?branch=stable)
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)

# Docs
- [L4D2 Director Scripts](https://developer.valvesoftware.com/wiki/L4D2_Director_Scripts)

# Supported Platforms
- Windows
- Linux

# Supported Games
- Left 4 Dead 2
- Left 4 Dead (soon; requires gamedata)
