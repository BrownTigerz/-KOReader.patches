# BookOrbit Tweaks Changelog

## 2.17.1 (2026-11-18)

- **A server you pick by hand now stays picked.** With Pick Server By Wi-Fi on, switching servers in the Tweaks menu (or the saved-servers picker) was undone as soon as BookOrbit reopened: on your home Wi-Fi it went straight back to the home server. A hand-picked server now holds for as long as that Wi-Fi connection lasts.
- When the Wi-Fi disconnects (turned off, lost, or off for sleep), or you move to a different network, the hold ends and Pick Server By Wi-Fi takes over again. Picking a server while offline holds nothing.
- Changing any Pick Server By Wi-Fi setting (on/off, Home Wi-Fi, Home Server, Away Server) also makes it apply again. A restart does too.

## 2.17.0 (2026-11-17)

- **Add To Collection uses a BookOrbit API key** (server 3.8.0+, Read and write) instead of the website password.
- **Shared with OrbitShelf**: same encrypted store (`settings/orbitshelf_api_key.lua` / keyring) and temp file (`koreader/orbitshelf_api_key.txt`). Enter the key once; both use it.
- **Create API Key File** in the Tweaks menu writes the temp template on demand.
- Temp file explains itself; deleted after a successful import.
- Menu: Create API Key File / Forget Saved API Key / About The API Key (replaces the password items). About is scrollable.
- Old saved website password for collections is no longer used (safe to ignore leftover `bookorbit_tweaks_login.lua`).

## Earlier

See git history for 2.16.x and below (password-based Add To Collection, Pick Server By Wi-Fi, action colours, etc.).
