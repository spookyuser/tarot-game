# Tarot Roguelike

A tarot card reading game built in Godot 4.6. Clients arrive with problems; you draw from a 78-card deck and place cards into reading slots to shape their fate.

## Credits

- **Audio** — Ted Buxton (Granular Biomes) Thanks Ted!
- **Cards** — [finalbossblues](https://finalbossblues.itch.io/pixel-tarot-deck)
- **UI** — [Oink55](https://oinky55.itch.io/fantasy-ui)
- **Portraits** — [LYASeeK](https://lyaseek.itch.io/minifvillagers)
- **Font** — [Spectral](https://github.com/productiontype/Spectral) (SIL OFL 1.1)

## Love2D Migration (WIP)

A playable Love2D port scaffold now exists with:
- Fixed-size 1280x720 window and game bootstrap (`conf.lua`, `main.lua`)
- Card/deck/hand/slot drag-drop interactions
- Explicit FSM flow (`init -> client_loading -> intro -> reading_active -> resolution -> game_end`)
- Hardcoded client content and generated local readings

Run with Love2D from repo root:

```bash
love .
```
