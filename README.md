# Nordens Paris - Mistweaver Monk Addon

A comprehensive Renewing Mist tracker for Mistweaver Monks in WoW Classic MoP.

## Features

### Core Tracking (Mistweaver Only)
- **Renewing Mist Tracking**: Real-time tracking of Renewing Mist on all party/raid members with progress bars
  - Shows remaining duration for each player
  - Color-coded by urgency (green > 10s, yellow 5-10s, orange 3-5s, red < 3s)
  - Automatically adjusts frame height based on number of active targets
- **Uplift Counter**: Shows how many targets would be healed by Uplift
  - Visual highlight when 3+ targets are active (optimal Uplift timing)
  - Flashing green background for emphasis
- **Jade Serpent Statue Monitor**: Duration and status tracking for your Jade Serpent Statue
  - Shows time remaining with color-coded urgency
  - "Not Summoned" indicator when inactive
  - Dimmed display when statue is down

### Group Utilities
- **Spinning Crane Kick Optimizer**: Smart detector for optimal SCK usage
  - Visual indicator when 3+ injured targets are within 8 yards
  - Shows exact count of targets in range
  - Health threshold detection (only counts injured players)
- **External Cooldown Tracker**: Monitor major healing cooldowns from other healers
  - Tracks: Tranquility, Divine Hymn, Revival, Spirit Link Totem, Healing Tide Totem, Ancestral Guidance, Aura Mastery
  - Shows player name, cooldown name, and remaining duration
  - Automatically detects and tracks cooldowns used by raid members
  - Reset button to clear tracked cooldowns
- **Loot Roll Tracker**: Monitor item rolls and player selections
  - Tracks Need, Greed, Pass, and Disenchant rolls
  - Shows item link, roll type, and roll value
  - Tracks which players have made selections
  - Auto-cleanup after roll completes
  - Scroll support for viewing many rolls
  - Persistent position saving

### UI & Performance
- **Draggable Frame**: Unlock to reposition, lock to prevent accidental movement
- **Memory Usage Display**: Real-time addon memory footprint monitoring
- **Color-Coded Display**: Visual indicators for buff coverage and urgency throughout
- **Performance Optimized**: Smart caching and throttling for smooth performance in 40-man raids

## Commands

### Frame Management
- `/np lock` - Lock the frame position
- `/np unlock` - Unlock the frame for repositioning
- `/np reset` - Reset frame position to default

### Feature Toggles
- `/np mist` (or `renewing`) - Toggle Renewing Mist tracker
- `/np statue` - Toggle Jade Serpent Statue tracker
- `/np cooldowns` (or `cds`) - Toggle external cooldown tracker
- `/np sck` (or `crane`) - Toggle Spinning Crane Kick optimizer
- `/np loot` (or `rolls`) - Toggle loot roll tracker
- `/np memory` (or `mem`) - Toggle memory usage display

### Information
- `/np help` - Show command list and current status

## Installation

1. Copy the addon folder to `World of Warcraft\_classic_\Interface\AddOns\`
2. Restart WoW or reload UI with `/reload`
3. Use `/nphelp` to see available commands

## Feature Suggestions & Roadmap

### High Priority
- [ ] **Thunder Focus Tea Tracker**: Show when TFT is active and suggest optimal spells to use
- [ ] **Mana Tea Counter**: Track stacks and when to consume for maximum efficiency
- [ ] **Chi Counter**: Visual chi counter with prominent display
- [ ] **Soothing Mist Channel Indicator**: Show current channel target and duration
- [ ] **Revival Cooldown Tracker**: Big visual indicator when Revival is available
- [ ] **Life Cocoon Tracker**: Show active cocoons on raid members with remaining shields
- [ ] **Essence Font Tracker**: Show when buff is active and on how many targets

### Display & UI Enhancements
- [ ] **Customizable Frame Layouts**: Allow users to arrange trackers independently
- [ ] **Scale Options**: Individual scaling for each tracker module
- [ ] **Color Customization**: Allow custom colors for all status indicators
- [ ] **Font Options**: Customizable fonts and sizes
- [ ] **Transparency Settings**: Adjustable background opacity
- [ ] **Anchor Points**: Custom anchor points for all frames
- [ ] **Compact Mode**: Minimal display showing only essential information
- [ ] **Sound Alerts**: Audio notifications for key events (Uplift ready, TFT active, etc.)
- [ ] **Flash/Glow Effects**: More prominent visual alerts for important procs

### Advanced Tracking
- [ ] **Enveloping Mist Tracker**: Show active Enveloping Mists with duration
- [ ] **Expel Harm Ready Indicator**: Highlight when self-damage warrants usage
- [x] **Spinning Crane Kick Optimization**: Show when 3+ injured targets are stacked
- [ ] **Zen Sphere Tracker**: Monitor active Zen Spheres and suggest reapplication
- [ ] **Mastery Bonus Calculator**: Real-time display of Gust of Mists value
- [ ] **Ancient Teachings of the Monastery**: Track blackout kick bonus healing
- [ ] **Crane Stance Indicator**: Show when in DPS stance with warnings

### Smart Suggestions & Alerts
- [ ] **Mana Management Warnings**: Alert when mana is critically low
- [ ] **GCD Waste Tracker**: Identify idle time during combat
- [ ] **Overheal Statistics**: Per-session tracking of healing efficiency
- [ ] **Target Priority Suggestions**: Highlight raid members who need healing most
- [ ] **Cooldown Recommendations**: Suggest when to use major cooldowns based on raid damage
- [ ] **Buff Expiration Warnings**: Alert X seconds before important buffs expire
- [ ] **Range Checker**: Highlight out-of-range party/raid members

### Group Coordination
- [ ] **Other MW Monk Detection**: Show Renewing Mists from other Mistweavers
- [x] **External Cooldown Tracker**: Track major healing CDs from other healers
- [ ] **Healer Mana Display**: Show mana status of all healers in raid
- [ ] **Healing Assignment Helper**: Mark/track assigned healing targets
- [ ] **Interrupt Coordination**: Track available interrupts in party

### Combat Analytics
- [ ] **Session Statistics**: Healing done, overhealing %, mana efficiency
- [ ] **Spell Usage Counter**: Track casts per ability during combat
- [ ] **Uptime Tracking**: HoT uptime percentages per target
- [ ] **Healing Per Mana**: Real-time HPM calculations
- [ ] **Combat Log**: Recent healing events with timestamps
- [ ] **Wasted Procs**: Track Thunder Focus Tea expiration without use
- [ ] **Performance Metrics**: APM, reaction time to raid damage

### Automation & Integration
- [ ] **WeakAuras Integration**: Export data for custom WeakAuras
- [ ] **Raid Frame Integration**: Option to show Renewing Mist dots on default raid frames
- [ ] **Boss Mod Integration**: Prepare suggestions based on known boss mechanics (DBM/BigWigs)
- [ ] **Profile System**: Save/load different configurations for raids vs. dungeons
- [ ] **Auto-Configuration**: Preset layouts for different content types

### Quality of Life
- [ ] **Mouseover Tooltips**: Detailed information on hover
- [ ] **Click-Through Frames**: Option to make frames non-interactive during combat
- [ ] **Combat State Toggles**: Auto-hide certain elements outside combat
- [ ] **Test Mode**: Preview all trackers with simulated data
- [ ] **Import/Export Settings**: Share configurations between characters
- [ ] **Reset to Defaults**: Easy reset button for all settings
- [ ] **Minimap Button**: Quick access to settings and toggles

### Advanced Techniques
- [ ] **Fistweaving Helper**: Track blackout kick + jab timing
- [ ] **Statue Positioning Reminder**: Visual indicator if statue is poorly placed
- [ ] **Renewing Mist Bounce Predictor**: Predict next target for RM bounce
- [ ] **Chi Torpedo Path Tracker**: Show optimal paths for movement + healing
- [ ] **Diffuse Magic/Dampen Harm Tracker**: Monitor defensive cooldowns

### Performance & Optimization
- [x] **Update Throttling**: Reduce update frequency for better performance in 40-man raids
- [x] **Memory Usage Display**: Show addon memory footprint
- [x] **CPU Usage Optimization**: Profile and optimize expensive operations
- [ ] **Selective Tracking**: Enable/disable features based on content type

### Technical Improvements
- [ ] **Modular Plugin System**: Allow community-created modules
- [ ] **API Documentation**: Document exported functions for developers
- [ ] **Localization Support**: Multi-language support
- [ ] **Classic Era Support**: Backport to WoW Classic Vanilla
- [ ] **Retail Support**: Forward port to modern WoW

## Contributing

Suggestions and contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT License
