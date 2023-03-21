## \[TTT2\] Tapir \[Class\]

Includes a silly TTT2 Class that can spawn a friendly Tapir which fights for you.
Players damaged by the Tapir will suffer the "drowsy" status effect which will obscure their screen and play Touhou music on their end.
The concept is inspired by [Doremy Sweet](https://en.touhouwiki.net/wiki/Doremy_Sweet).

If you're not using the class but want to spawn a tapir in your own code, use the global `function SpawnTapir(owner: Player)`.

### Dependencies

- [Tapir models](https://steamcommunity.com/sharedfiles/filedetails/?id=1327409757)
- [TTT2](https://steamcommunity.com/sharedfiles/filedetails/?id=1357204556)
- [TTTC](https://steamcommunity.com/sharedfiles/filedetails/?id=1368035687) (optional, obviously needed for the class)

### ConVars

| ConVar                          |                               Default | Description                                                                                      |
| ------------------------------- | ------------------------------------: | ------------------------------------------------------------------------------------------------ |
| ttt_tapir_health                |                                   400 | How much health should the tapir have?                                                           |
| ttt_tapir_damage                |                                     4 | How much damage should the tapir do with its attacks?                                            |
| ttt_tapir_close_distance        |                                   100 | How closely should the tapir follow its owner? (in hammer units)                                 |
| ttt_tapir_drowsy_duration       |                                    30 | How long should the drowsiness effect last in seconds? (def: 30, set to 0 to disable)            |
| ttt_tapir_drowsy_volume         |                                   1.0 | How loud shoud the drowsiness music be? (1.0 means 100%, i.e. the normal volume of the file)     |
| ttt_tapir_drowsy_audio          | touhou/eternal_spring_dream_short.ogg | The audio file to play for drowsy players, relative to "sound/" (set to empty string to disable) |
| ttt_tapir_drowsy_audio_length   |                                 51.25 | How long does the audio file play in seconds before it should be looped? (def: 51.25)            |
| ttt_tapir_drowsy_overlay_enable |                                     1 | Should drowsy players have a disorienting screen overlay effect?                                 |

### Copyright

This project is a fan work based on the Touhou Project.
Specifically, the files in the `sound/touhou/` directory belong to the Touhou Project and therefore do _not_ fall under the terms of this project's LICENSE.
As such, any derivative works of this project that also include that content will have to follow the [Guidelines for Touhou Project Fan Creators](https://touhou-project.news/guidelines_en).
