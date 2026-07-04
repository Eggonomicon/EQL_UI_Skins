# EQL UI Skins

Custom UI skins for EverQuest Legends.

This repository currently contains the Modern UI line: a dark, high-resolution-friendly UI family built from the EverQuest Legends `default_modern` base and customized for larger displays, ultrawide layouts, and more readable spell/combat workflows.

## Included Skins

| Folder | Intended use |
| --- | --- |
| `Modern` | Baseline Modern skin for standard layouts and smaller high-resolution setups. |
| `Modern_2K_120` | 2K/QHD-oriented version, roughly targeting 2560x1440 with larger UI elements. |
| `Modern_3440x1440_120` | Ultrawide version for 3440x1440. |
| `Modern_4K_120` | 4K version using the 120% scale family. |
| `Modern_4K_150` | Larger 4K version for players who want bigger controls/text. |

## Screenshots

### Modern_3440x1440_120

![Modern_3440x1440_120 screenshot](screenshots/Modern_3440x1440_120.png)

## Modern UI Features

- Dark modernized window styling based on EverQuest Legends `default_modern`.
- Scaled UI variants for 2K, 3440x1440 ultrawide, and 4K displays.
- Hotbar, spell bar, buff, debuff, inventory, item display, AA, and spellbook usability tuning.
- Vertical buff/debuff layouts with spell icons and duration bars.
- Spellbook rows with spell icons, colored spell-type bars, and readable left-aligned spell names.
- Item display window spacing fixes for upgrade progress text, merge/place item controls, and stat blocks.
- Restored default-color coin and spellbook icons.

## Installation

1. Download or clone this repository.
2. Copy the desired skin folder into your EverQuest Legends UI folder.

   Example:

   ```text
   EverQuest Legends/UIFiles/Modern_3440x1440_120
   ```

3. In game, open the UI skin loader and choose the copied folder.
4. Keep your current layout if you want to preserve window positions.

You can also load a skin from chat with:

```text
/loadskin Modern_3440x1440_120
```

Replace the folder name with the skin variant you want to use.

## Choosing a Version

For 3440x1440 ultrawide, start with:

```text
Modern_3440x1440_120
```

For 4K, start with:

```text
Modern_4K_120
```

If 4K text and controls still feel too small, use:

```text
Modern_4K_150
```

## Troubleshooting

If the game falls back to the default UI, check `UIErrorLog.txt` in your EverQuest Legends directory. XML reference errors usually mean a missing asset, missing animation declaration, or a mismatched XML name.

Useful things to include when reporting an issue:

- Skin folder name.
- Your resolution and UI scale.
- Screenshot of the broken window.
- Relevant `UIErrorLog.txt` lines.
- Which window or control is affected.

## Validation

The Modern skin XML files were locally parsed before upload. The current upload set includes 1,285 XML files across the Modern variants.

## Notes

These skins are a work in progress and are tuned around EverQuest Legends behavior. Some windows are resizable in game, so layout polish may vary depending on saved window size and screen resolution.
