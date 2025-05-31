# EZPR - Easy Pull Request Review for Neovim

A Neovim plugin for reviewing Azure DevOps pull requests directly in your editor with a three-panel
layout.

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

The layout creates normal Neovim windows and buffers, so you can use your existing window navigation
keymaps (like `<C-w>h/j/k/l` or any custom mappings you have configured).

### Built-in Actions

- `Enter` - Select item in files or discussions panels
  - In files panel: Load file into main window and update discussions
  - In discussions panel: Jump to relevant line in main window

### Normal Vim Navigation

- Use your normal window navigation commands to move between panels
- Use normal buffer navigation (`j/k`, `/`, `?`, etc.) within each panel
- All standard Vim motions work within each buffer

## Commands

### Pull Request Review

- `:EzprListPRs` - List all pull requests and select one to review
- `:EzprOpenDiscussion` - Open all discussions at current cursor line

### Layout Management

- `:EzprUI` - Toggle the UI layout on/off
- `:EzprOpen` - Open the UI layout
- `:EzprClose` - Close the UI layout

### Testing

- `:EzprTestUI` - Create layout with placeholder content for testing
- `:EzprDemoNav` - Demonstrate navigation between panels

## Panels Description

### Main Window (Left)

- Shows side-by-side diff view of selected file (original vs PR version)
- For new files, shows single file view with PR content
- Highlights specific text ranges that have discussions
- Virtual text indicators show discussion summaries at end of lines
- Updates when a file is selected from the files panel

### Discussions Panel (Top Right)

- Shows all discussions for the currently selected file
- Each discussion shows line number, comment count, and author
- Selecting a discussion jumps to that line in the main window

### Files Panel (Bottom Right)

- Shows list of all changed files in the pull request
- Files show change type indicators (+, ~, -)
- Selecting a file loads it into the main window and updates discussions

## Current State

EZPR is now a fully functional pull request review tool with Azure DevOps backend integration.

### What Works

- ✅ Three-panel layout creation and management
- ✅ Azure DevOps authentication via Azure CLI
- ✅ Pull request listing and selection
- ✅ File diff loading (side-by-side and single file views)
- ✅ Discussion fetching and display
- ✅ Text range highlighting for discussions
- ✅ Virtual text indicators for discussion locations
- ✅ Discussion popup windows with full comment threads
- ✅ Panel navigation and window management
- ✅ Line jumping from discussions to code

## TODO

1. ✅**Multiple discussions on the same line**: UI should clearly show multiple items (both virtual
   text and the multiple discussions)
2. ✅ **Auto-focus file picker**: When ezpr UI kicks in, start with a focus on the file picker
3. ✅**Comment on text**: Add ability to comment on selected text (in visual mode)
4. **Reply to a discussion**: Implement functionality to reply to existing discussions
5. ✅**Change state of a discussion**: Add ability to resolve/unresolve discussions
6. ✅ **Panel width optimization**: Adjust panels to be about 20% of total width
7. ✅ **Remove excessive notifications**: Remove UI notifications for normal behavior (loading
   files, jumping to lines, etc.)
8. **Loading indicators**: Add spinner or progress indicators when loading PRs, files, and
   discussions
9. **Enhanced thread state UI**: Improve discussion list presentation with better visual state
   indicators
   - Grey out non-active threads (resolved/outdated) in the discussions panel
   - Format discussion titles with better styling and state indicators
   - Add icons or prefixes to clearly distinguish thread states (🟢 Active, ✅ Resolved, ⚠️
     Outdated)
   - Consider different text colors/weights for different states
10. **Interactive discussion popup**: Enhance floating discussion window interaction
    - Auto-focus cursor inside the floating discussion window when opened via `:EzprOpenDiscussion`
    - Add 'q' key binding to quit/close the floating window and return focus to main content
    - Enable scrolling and navigation within the discussion popup
    - Consider adding reply functionality directly from the popup
11. **Timezone correction**: Fix timezone conversion in discussion popups (currently off by 1 hour)
12. **Visual enhancement for inactive discussions**:
    - Darken non-active discussions in the discussion panel (similar to virtual text)
    - Darken non-active discussions in the files panel as well
    - Use consistent visual hierarchy for active vs inactive states across all UI components

## Setup Requirements

- Azure CLI installed and authenticated
- Access to Azure DevOps repositories
- Git repository with Azure DevOps remote

