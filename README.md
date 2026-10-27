# Stranded Island

A Roblox survival game where you're stranded on an island. Chop trees, mine rocks,
find rare loot, level up, and come back every day for a growing login streak.

The code lives in this repo and gets synced into Roblox Studio with [Rojo](https://rojo.space).
You build the map (the island, water, props) in Studio as normal.

## What's in the starter

- **Gathering**: walk up to a Tree or Rock and hold **E** to chop/mine it. Every hit gives
  resources, the last hit gives a bonus, and the node respawns after a while.
- **Juicy feedback**: floating "+3 🪵 Wood" pop-ups, flying chips, a combo sound that rises
  in pitch when you gather fast, random **LUCKY x2!** hits, and **RARE FIND!** banners
  (🥥 Coconut from trees, 💎 Gem from rocks).
- **Inventory panel** (bottom left) with numbers that count up and bounce. Rare items stay
  hidden until you find your first one.
- **Levels and XP** with a bar at the top and a **LEVEL UP!** banner.
- **Daily login streak**: bigger reward each day in a row, up to day 7.
- **Saving** with DataStores, so everything is still there next time.

If your map has no Trees or Rocks yet, the game drops a few around spawn so you can play
on an empty Baseplate right away.

## Folder layout

| Folder | Ends up in Studio as | What goes here |
| --- | --- | --- |
| `src/server` | `ServerScriptService.Server` | Server scripts (saving, gathering, rewards) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | UI and effects for each player |
| `src/shared` | `ReplicatedStorage.Shared` | Things both sides use, like `Config.luau` |

Want to change drop amounts, respawn times, rare chances, or XP? It's all in
`src/shared/Config.luau`.

## Getting it running (Windows)

You only do steps 1 to 3 once.

1. **Get the code.** On the GitHub page click the green **Code** button, then
   **Download ZIP**. Unzip it somewhere easy like `Documents\stranded-island`.
   (If you use Git: `git clone https://github.com/polybotmarket9/stranded-island.git`.)
2. **Get Rojo.** Go to <https://github.com/rojo-rbx/rojo/releases>, open the newest 7.x
   release, and download the file ending in `windows-x86_64.zip`. Unzip it and copy
   `rojo.exe` into your `stranded-island` folder (next to `default.project.json`).
3. **Install the Studio plugin.** Close Roblox Studio. Open the `stranded-island` folder in
   File Explorer, click the address bar, type `powershell` and press Enter. In the blue
   window that opens, run:
   ```powershell
   .\rojo.exe plugin install
   ```
   If Windows warns about the file, click **More info** then **Run anyway**.

Every time you want to work on the game:

4. **Start Rojo.** Open PowerShell in the folder again (address bar, `powershell`, Enter) and run:
   ```powershell
   .\rojo.exe serve
   ```
   Leave this window open. It should say it's listening on port 34872.
5. **Connect Studio.** Open Roblox Studio and open your place (a new **Baseplate** is fine).
   Go to the **Plugins** tab, click **Rojo**, then click **Connect**.
   The scripts appear in Explorer under ServerScriptService, StarterPlayerScripts and
   ReplicatedStorage.
6. **Play.** Press **Play** (F5). Walk to a tree and hold **E**.

Any change you save to a file in `src` shows up in Studio instantly while Rojo is connected.

### Turning on saving in Studio

DataStores only work in Studio after you publish the place and turn on access:
**File > Publish to Roblox**, then **Home > Game Settings > Security >
Enable Studio Access to API Services**. Without this the game still plays, it just
won't remember your stuff between sessions (you'll see a warning in Output).

## Adding your own trees and rocks

Build or import a tree/rock in Studio and name the Part or Model **`Tree`** or **`Rock`**.
That's it. The game finds it, adds the "Chop"/"Mine" prompt, and handles respawning.
(You can also use the **Tags** section in Properties and add the tag `Tree` or `Rock`
if you'd rather keep your own names.) Once your island has its own nodes, the demo ones
stop appearing.

To add a new resource type, add it to `Config.ResourceOrder` and `Config.Resources`,
then add a node for it in `Config.Nodes`.
