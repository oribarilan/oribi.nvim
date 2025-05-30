# EZPR UI Layout

A simple three-panel layout for reviewing pull requests in Neovim.

## Layout Structure

```
┌─────────────────────┬─────────────────┐
│                     │   Discussions   │
│    Main Window      │  (Top Right)    │
│   (Diff/Content)    ├─────────────────┤
│     (Left)          │     Files       │
│                     │ (Bottom Right)  │
└─────────────────────┴─────────────────┘
```

## Navigation

The layout creates normal Neovim windows and buffers, so you can use your existing window navigation keymaps (like `<C-w>h/j/k/l` or any custom mappings you have configured).

### Built-in Actions
- `Enter` - Select item in files or discussions panels
  - In files panel: Load file into main window and update discussions
  - In discussions panel: Jump to relevant line in main window

### Normal Vim Navigation
- Use your normal window navigation commands to move between panels
- Use normal buffer navigation (`j/k`, `/`, `?`, etc.) within each panel
- All standard Vim motions work within each buffer

## Commands

### Layout Management
- `:EzprUI` - Toggle the UI layout on/off
- `:EzprOpen` - Open the UI layout
- `:EzprClose` - Close the UI layout

### Testing
- `:EzprTestUI` - Create layout with placeholder content for testing
- `:EzprDemoNav` - Demonstrate navigation between panels

## Panels Description

### Main Window (Left)
- Shows diff or content of the currently selected file
- Updates when a file is selected from the files panel
- Cursor jumps to relevant lines when discussions are selected

### Discussions Panel (Top Right)
- Shows all discussions for the currently focused file
- Each discussion shows line number and preview
- Selecting a discussion jumps to that line in the main window

### Files Panel (Bottom Right)
- Shows list of files in the pull request
- Each file shows discussion count in parentheses
- Selecting a file loads it into the main window and updates discussions

## Current State

This is the initial layout implementation with placeholder content. The layout structure and navigation are fully functional, but integration with actual PR data is not yet implemented.

### What Works
- ✅ Three-panel layout creation
- ✅ Panel navigation with Ctrl+h/j/k/l
- ✅ Within-panel navigation with j/k
- ✅ Window management and cleanup
- ✅ Placeholder content for testing

### Next Steps
- [ ] Integration with PR data from backends
- [ ] Actual file diff loading
- [ ] Discussion parsing and display
- [ ] Line jumping functionality
- [ ] Syntax highlighting
- [ ] Discussion creation/reply interface