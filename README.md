# Snow Job mod pack for Valheim

The mod list for **Snow Job**, a private Valheim server run for a group of friends, plus a
one-click updater that keeps everyone on the same mods.

Anyone is welcome to use this pack for their own game or server.

> **Unofficial, fan-made and non-commercial.** This project is not affiliated with or endorsed by
> Iron Gate AB, Coffee Stain Publishing or any mod author. Valheim is a trademark of its owners.
> Every third-party mod belongs to its author. We claim no ownership of them. The updater downloads
> them directly from each author's own Thunderstore page, and this repository does not host copies.

## For players

1. Download **[SnowJob-Updater.bat](https://raw.githubusercontent.com/JohmesSnow/SnowJob-Mods/main/SnowJob-Updater.bat)**
   (right-click the link, then choose *Save link as*). Put it anywhere, for example on your desktop.
2. Close Valheim, then double-click `SnowJob-Updater.bat`.
3. When it says it's finished, press **Y** to start Valheim, or start the game from Steam as usual.

Run it again whenever the group says the mods changed. It only downloads what is new or different,
so a run with nothing to do takes a few seconds.

If Windows shows "Windows protected your PC", click **More info**, then **Run anyway**. That
warning appears for any downloaded batch file.

Requirements: Windows and the Steam version of Valheim. Console and Game Pass versions cannot be
modded.

### What the updater does

- Finds your Valheim folder through Steam, or asks for it.
- Installs BepInEx, the mod loader, if you don't already have it.
- Installs or updates every mod in the list below, and removes mods the pack has dropped.
- Installs a few default settings files. It only replaces one when the pack publishes a new
  version, and it keeps your old copy as `<name>.cfg.bak`.

### What it won't do

- Touch anything outside your Valheim folder.
- Remove or change mods and settings that aren't part of this pack.
- Download from anywhere except Thunderstore and this repository. Every file is checked against a
  SHA-256 checksum before it is written, and a file that doesn't match is refused.
- Run while Valheim is open.

## Mods in the pack

"Both" means the server and every player need the mod. "Client" means it only runs on your own game.

| Mod | Author | Side | What it does |
|---|---|---|---|
| [BepInExPack Valheim](https://thunderstore.io/c/valheim/p/denikson/BepInExPack_Valheim/) | denikson | Both | Mod loader |
| [Jotunn](https://thunderstore.io/c/valheim/p/ValheimModding/Jotunn/) | ValheimModding | Both | Modding library |
| [YamlDotNet](https://thunderstore.io/c/valheim/p/ValheimModding/YamlDotNet/) | ValheimModding | Both | Library used by Extra Slots |
| [Conditional Config Sync](https://thunderstore.io/c/valheim/p/shudnal/ConditionalConfigSync/) | shudnal | Both | Server-to-player settings sync |
| [Extra Slots](https://thunderstore.io/c/valheim/p/shudnal/ExtraSlots/) | shudnal | Both | Equipment panel, including a backpack slot |
| [Plant Everything](https://thunderstore.io/c/valheim/p/Advize/PlantEverything/) | Advize | Both | Plant berries, mushrooms, flowers and more |
| [Plant Easily](https://thunderstore.io/c/valheim/p/Advize/PlantEasily/) | Advize | Client | Grid planting |
| [Valheim Build Camera](https://thunderstore.io/c/valheim/p/Stonaar/ValheimBuildCamera/) | Stonaar | Client | Free camera while building (F6) |
| [BetterMap](https://thunderstore.io/c/valheim/p/xtavim/BetterMap/) | xtavim | Both | Automatic map pins |
| [OdinShip](https://thunderstore.io/c/valheim/p/Marlthon/OdinShip/) | Marlthon | Both | New cargo and war ships |
| [OdinHorse](https://thunderstore.io/c/valheim/p/OdinPlus/OdinHorse/) | OdinPlus | Both | Tameable, rideable horses |
| [Boat Anchor](https://thunderstore.io/c/valheim/p/KalellModding/BoatAnchor/) | KalellModding | Both | Drop anchor with Shift+E at the rudder |
| [HideBags](mods/HideBags) | Snow Job group | Both | Hide backpacks with extra rows, carry weight and a perk |
| [PlantedYield](mods/PlantedYield) | Snow Job group | Both | Bushes you plant yourself give more per pick |
| [TameFollow](mods/TameFollow) | Snow Job group | Client | Tamed boars and hens can follow or stay |

Exact versions and checksums are in [manifest.json](manifest.json).

## About the server

Mod settings that affect gameplay, such as recipes, carry weight, horse spawns and map sharing,
are locked by the server. Editing your own config files doesn't change them. The server's address and
password are shared privately within the group and never appear in this repository.

## For maintainers

- Edit `tools/pack.json` to add, remove or change the version of a mod. Put our own mods in
  `mods/` and the managed default settings in `configs/`.
- Run `python tools/build_manifest.py` to write `manifest.json` with fresh checksums.
- Test with a throwaway game folder:
  `powershell -File updater\SnowJob-Updater.ps1 -GameDir <folder> -ManifestPath manifest.json -LocalRepo . -NoPause`
- Commit and push. Players get the change the next time they run the updater.

## License

The updater, tools and the three Snow Job group mods (HideBags, PlantedYield, TameFollow) are
released under the MIT License, see [LICENSE](LICENSE). Third-party mods are **not** covered by that
license. They remain under their authors' own terms and are fetched from their original pages.
