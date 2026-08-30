Use this as the implementation prompt. Paste it as-is.  
  
---  
  
# Build Berth — macOS menu bar port UI  
  
You are implementing **Berth**, a native macOS menu bar app for viewing and releasing local listening ports. Build the **UI and interaction first**, with real data wired to `lsof` if possible, but the visual/interaction spec below is the source of truth.  
  
## Product  
  
Berth is a **berth map**, not another `lsof` table.  
  
- Menu bar only. No Dock icon. `LSUIElement = YES`.  
- English UI strings.  
- Native SwiftUI + AppKit. No Electron. No usage-ring / AI-quota aesthetic.  
- Primary action is **Release** (stop the process occupying a port), not a red X kill grid.  
  
Metaphor used once: occupied slip / empty slip / casting off. No boats, anchors, waves, or illustrations.  
  
## Interaction model to implement  
  
Do **not** copy circular percentage gauges. Borrow only this structure:  
  
1. Compact status entry in the menu bar.  
2. Click opens a **rounded floating card** with a caret pointing at the status item (popover), not a raw `NSMenu` list.  
3. The card has two layers:  
   - **Berth strip** on top: watched ports as slots.  
   - **Detail / project list** below.  
4. Clicking a slot selects it. Detail updates to that port. Do not jump to a new window.  
5. Releasing a port happens inside the card. The row does not vanish instantly.  
  
Optional later: a right-edge always-on capsule. **Do not build the edge bar in v0.1.** Menu bar + popover only.  
  
## Menu bar status item  
  
- Template SF Symbol or simple custom slot mark. Must work in light/dark/transparent menu bar.  
- Do **not** show total LISTEN count (that includes system ports).  
- If any watched dev ports are occupied, show a small count of **occupied watched ports** or **project count**.  
- Slots conceptually: filled = occupied, hollow = free. If the status item cannot render multiple slots cleanly, use icon + count. Full slot strip lives in the popover.  
  
Watched ports default:  
`3000, 3001, 4000, 4173, 5000, 5173, 5432, 6379, 8000, 8080, 8888, 9000, 27017`  
  
## Popover chrome  
  
- Width ~380–420 pt.  
- Max height ~560 pt, content scrolls under a sticky header.  
- Corner radius large, system material / dark elevated card is fine.  
- Caret attached to the status item.  
- No standard app menu bar. No Dock.  
  
Sticky header:  
  
1. Command field (search + actions)  
2. Berth strip  
3. Segmented filter: `All | Dev | Data | Exposed`  
  
Footer:  
  
- Status text on the left `Released :3000`, errors)  
- Gear (Settings) and Quit on the right  
  
## Berth strip  
  
Horizontal slots, one per watched port (wrap if needed, but prefer a single wrapping row).  
  
Each slot shows the port number and state:  
  
| State | Look |  
|---|---|  
| Empty | Hollow slot, muted |  
| Occupied | Filled slot, primary emphasis |  
| Releasing | Pulse / dim + “…” |  
| Conflict | Occupied + thin warning mark |  
| Exposed | Occupied + tiny “LAN” mark if bound to `0.0.0.0` or `*` |  
  
Click a slot:  
  
- Selects it  
- Scrolls/filters the list to that port’s project  
- Detail panel shows that slip  
  
Empty watched ports **stay visible** in the strip. That is the point: you can see `:5173` is free.  
  
## Main list: project cards, not process rows  
  
Group by project (git repo name, else directory name, else package name). Never lead with `node`.  
  
Card collapsed:  
  
```  
blog-web                         12m  
next · :3000 :4000               local  
```  
  
Card expanded (selected or disclosure):  
  
```  
blog-web                         12m  
:3000  next     local     [Open] [Release]  
:4000  nest     local     [Open] [Release]  
cwd ~/code/blog-web  
```  
  
Rules:  
  
- Same project, multiple ports = one card.  
- Databases/redis/mongo are a separate group. **No primary Release button** on those cards. Release lives in `•••` with copy: “This is a database. Stopping it will break local apps.”  
- System ports hidden by default in a collapsed `System` group. No Release button.  
- Bind address shown as `local` `127.0.0.1` / `::1`) or `LAN visible` `0.0.0.0` / `*`), not raw addresses as the primary label.  
- PID, full command, raw address belong in `•••` or expanded detail.  
  
## Release interaction (must implement)  
  
Primary button label: **Release**    
Not “Kill”. Not a red X on every row.  
  
Flow:  
  
1. User clicks Release on a dev port.  
2. Row/slot enters **Casting off** state immediately.  
3. Send SIGTERM to every LISTEN PID on that port (IPv4 + IPv6).  
4. For node/vite/next/python, also terminate the process tree (children first).  
5. Rescan immediately (do not wait for the 3s poll).  
6. If the port is free: slot becomes empty, footer says `Released :3000`, keep the empty slot in the strip.  
7. If still listening after ~2s: keep occupied, footer says `Still in use. Force release?` with a Force action.  
8. **Force release** (SIGKILL) is behind `•••` or Option-click on Release. Confirm:    
   `Force release pid 18422 (next · blog-web)? Unsaved work will be lost.`  
  
Protected processes: launchd, WindowServer, kernel_task, syslogd, mDNSResponder, and similar. Disable Release and show why.  
  
After success, do not remove watched ports from the strip.  
  
## Command field  
  
The search box is a command bar.  
  
- `3000` → select that slot  
- `blog` → filter cards  
- `release 3000` / `kill 3000` → release that port  
- `open 5173` → open `http://localhost:5173`  
  
Placeholder: `Find port, project, or command`  
  
## Settings window  
  
Separate small window, not inside the popover.  
  
- Launch at login  
- Refresh interval 1–15s (default 3)  
- Show count in menu bar  
- Show system ports  
- Edit watched ports  
- Quit is already in the popover footer  
  
Opening Settings may temporarily activate the app; closing returns to accessory policy.  
  
## Data  
  
Scan listening TCP only:  
`lsof -nP -iTCP -sTCP:LISTEN -F pcPnTu`  
  
Enrich with cwd, command, project name, framework from cmdline `next`, `vite`, `nuxt`, `uvicorn`, `postgres`, `redis-server`, `docker-proxy`, etc.).  
  
Poll every 3s and on popover open. Always rescan after Release.  
  
## Visual don’ts  
  
- No circular percentage rings  
- No traffic-light rainbow dashboard  
- No red X column  
- No “12 ports” menu bar badge that includes system daemons  
- No NavigationStack inside Settings  
- No main window at launch  
  
## Suggested SwiftUI structure  
  
```  
BerthApp  
  MenuBarExtra + LSUIElement  
  Settings scene  
  
PopoverView  
  CommandField  
  BerthStrip  
  FilterBar  
  ProjectCardList  
  FooterStatus  
  
Models  
  PortSlip  
  ProjectBerth  
  SlipState: empty | occupied | releasing | conflict  
  BindScope: local | lan  
  Terminator  
  Scanner  
```  
  
## v0.1 acceptance for this UI  
  
- Launch: menu bar only, no Dock icon.  
- Popover looks like a floating card with a berth strip on top.  
- Watched empty ports remain as hollow slots.  
- Selecting a slot drives the detail below.  
- Release uses casting-off state, then empty slot + footer confirmation.  
- Two node apps in different repos appear as two project cards, not two “node” rows.  
- System ports are not the first thing on screen.  
- Force release requires confirmation.  
- Option-click Release (or `•••`) is the only immediate SIGKILL path.  
  
Implement this UI/interaction faithfully. If you must trade scope, keep the berth strip, project cards, and release states; drop extras.  
  
---  
  
If you want a shorter version for a single Claude turn, use only from **Interaction model** through **v0.1 acceptance**.