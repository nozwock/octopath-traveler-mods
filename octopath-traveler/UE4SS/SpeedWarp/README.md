# Speed Warp
Automatically increases game speed during combat and allows cycling through a list of speeds, with configuration support.

## Usage
In and out of combat, you can cycle through different game speeds using either the `"Travel Banter"`, or a custom `GameSpeedCycle` key, set to `F8` by default.

By default,
- Game speed is automatically increased during combat, to a value set in the settings.
- Game speed-ups in combat mode apply only after the player has chosen a battle action.

Settings can be customized in the [settings.lua](Scripts/settings.lua) file. The settings file looks like this:
https://github.com/nozwock/octopath-traveler-mods/blob/a1b947f0a85083d14753afc42a6340a3f49ac730/octopath-traveler/UE4SS/SpeedWarp/Scripts/settings.lua#L5-L42
