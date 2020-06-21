This plugin allows automatically changing the map after a certain number of rounds. Players can vote for one of four displayed maps. Similar to the old Fretta gamemode, players can see how many votes each map has and change their own vote at any time.

The displayed maps can either be the four least recently played maps, or four random maps.

Colours can be customised to suit your server. If you have a web server, can also display a thumbnail for each map.

# Configuration

Once installed, the first time this plugin runs it will automatically generate a config file in
`data/jw-ttt-map-voting/`. The config is an unformatted JSON file. Use a [JSON prettifier](https://jsonformatter.org/)
to add formatting so it's easy to edit. Below is an explanation of the available options:

```jsonc
{
	"roundsPerMap": 8, // How many rounds should be played before voting commences
	"votingTime": 15, // How long should voting last? (in seconds)
	"catchupTime": 1.5, // How long the server waits after voting has ended before tallying votes (compensates for lag)
	"reflectionTime": 5, // How long to show players the result of the vote before changing the map
	"allowRTV": true, // Currently unused
	"limitByPlayers": true, // Hide certain maps based on number of players currently online
	"limitToNewestVersion": true, // Hide outdated maps
	"prioritiseLeastRecentlyPlayedMaps": true, // Allow voting on only the four least recently played maps. Otherwise, the four maps displayed are random.

    // The following options relate to importing maps. If maps are discovered in the garrysmod/maps directory that aren't currently in the configured maplist, the plugin will automatically import them into the map list.
    // During the import, we try to parse the map name into something more readable. As part of this, we also try to understand any version numbering that's present in the map name. For example, v3_fix.
    // Version numbers are split into two components: bigVersion (which is used for things like alpha/beta/release/final) and smallVersion (which is used for things like v3)
	"newMapsDefaultEnabled": false,
	"defaultBigVersion": 4, // Default bigVersion to use if we can't work it out from the map name. 4 == "release"
	"defaultSmallVersion": 0, // Default smallVersion to use if we can't work it out from the map name.
	"clientside": {
		"titleMargin": 15,
		"defaultThumbnail": "http://example.org/images/logo.png", // Thumbnail to use on maps without their own thumbnail.
		"thumbnailLocation": "http://example.org/images/mapthumbnails/", // Where map thumbnails can be found.
		"avatarSize": 64, // Must be one of the following: 16, 32, 64 (if useMegaAvatar is turned off then 128 can also be used) 32 recommnded for large servers (~50 slots), 64 should work for small servers (<24 slots)
		"maxAvatarRows": 5,
		"useMegaAvatar": true, // Whether players should see their own avatar at 4x the size
        // The following options relate to the animation when players change their vote.
		"animateAvatarMovement": true,
		"avatarSpeed": 128,
		"megaAvatarSpeed": 96,
		"avatarR1": 32,
		"avatarR2": 256,
		"avatarR1Tightness": 1,
		"avatarR2Tightness": 0.3,
		"avatarR1SpeedScale": 0.2,
		"avatarR2SpeedScale": 1,
        // The following options relate to the progress bar, which indicates how much time is remaining in the vote.
		"progressBarBackgroundColor": {
			"r": 31,
			"g": 67,
			"b": 118,
			"a": 255
		},
		"progressBarForegroundColor": {
			"r": 51,
			"g": 113,
			"b": 200,
			"a": 255
		},
		"progressBarHeight": 32,
		"progressBarInterval": 0 // Allows you to control how frequently, in seconds, the progress bar ticks. If zero, the progress bar will move continuously.
	}
}
```

The plugin will also generate a file called `maps.txt` in the same directory. This file will be automatically updated whenever a new map is detected. Again, it's unformatted JSON, so to make changes you'll need to run it through a formatter. It looks something like this:

```jsonc
[
    "ttt_67thway_v6": { // The map name on disk, without the .bsp extension
        "enabled": true, // If the map should appear in voting. Default value depends on the newMapsDefaultEnabled config option.
        "name": "67thway (TTT)", // Friendly name displayed to players.
        "thumbnail": "ttt_67thway_v6.jpg", // Name of the thumbnail to look for. (By default, the same as the map file but with the .bsp extension changed to .jpg)

        // The following values are used if the limitByPlayers option is enabled
        "minPlayers": -1, // Hide map if less than this many players are online (useful for big/sparse maps)
        "maxPlayers": -1, // Hide map if more than this many players are online (useful for small/cramped maps)

        // The following values are used if limitToNewestVersion is enabled
        "releaseBig": 4, // Release
        "releaseSmall": 6, // v6

        // The following values are updated automatically when the map list is loaded, so there's no point modifying them
        "exists": true, // If the map is deleted from disk, it remains in the config but will be disabled.
        "highestVersion": true // Whether this is the highest version map with this name.
    },
    "ttt_clue_fix": {
        "enabled": true,
        "name": "Clue (TTT)",
        "thumbnail": "ttt_clue_fix.jpg",
        "minPlayers": -1,
        "maxPlayers": -1,
        "releaseBig": 4,
        "releaseSmall": 1,
        "exists": true,
        "highestVersion": true
    },
    // ...
]
```

# Administration

Changes to config/map list will generally be loaded when the map changes. If you'd like to load them immediately, run the following console commands on the server:

```
lua_run MAPVOTE.loadConfig()
lua_run MAPVOTE.loadMaps()
```

If you'd like to force a vote after this round:

```
lua_run MAPVOTE.roundsSinceLastChange = MAPVOTE.config.roundsPerMap
```

If you'd like to extend the current map for a certain amount of rounds:

```
lua_run MAPVOTE.roundsSinceLastChange = MAPVOTE.config.roundsPerMap - 5
```