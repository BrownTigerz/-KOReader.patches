# BookOrbit Tweaks Changelog

## 2.17.0 (2026-11-17)

- **Add To Collection uses a BookOrbit API key** (server 3.8.0+, Read and write) instead of the website password.
- **Shared with OrbitShelf**: same encrypted store (`settings/orbitshelf_api_key.lua` / keyring) and temp file (`koreader/orbitshelf_api_key.txt`). Enter the key once; both use it.
- **Create API Key File** in the Tweaks menu writes the temp template on demand.
- Temp file explains itself; deleted after a successful import.
- Menu: Create API Key File / Forget Saved API Key / About The API Key (replaces the password items). About is scrollable.
- Old saved website password for collections is no longer used (safe to ignore leftover `bookorbit_tweaks_login.lua`).

## Earlier

See git history for 2.16.x and below (password-based Add To Collection, Pick Server By Wi-Fi, action colours, etc.).
