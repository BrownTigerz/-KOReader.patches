# -KOReader.patches

# ReadMastery Notify

A KOReader patch that adds a customizable notification system to ReadMastery. It provides visual feedback for events such as earning XP, completing quests, leveling up, and making reading progress.

The goal is to make ReadMastery's progression system feel more rewarding while keeping notifications clean, lightweight, and unobtrusive during reading.

# ReadMastery Quests

A KOReader patch that adds a quest and challenge system to ReadMastery. It introduces daily reading goals, progress-based quests, seasonal challenges, and special reading challenges that reward XP when completed.

The goal is to give reading more structure and variety while encouraging consistent reading without making the system overly complicated or distracting.

# Kobo Style Sleep Screen Banner

Download and ADD Famous Quotes.txt to file_path = "/mnt/onboard/.adds/Famous Quotes.txt"

Changes from the original
Custom quote fallback — if the current book has no eligible highlights, the patch automatically displays a random quote from a custom txt file.
No-repeat system — highlights and custom quotes have separate no-repeat windows to avoid seeing the same ones repeatedly.
Seeded randomization — improves random selection between KOReader restarts.
Automatic quote reloading — changes to quotes.txt are detected and the file is reloaded without needing to restart KOReader.
Removed unnecessary Sidecar:flush() — the patch only reads highlight data, so it no longer performs a flush every time the sleep screen appears.

# Custom Quotes for SimpleUI

300 famous quotes to use with simple ui, add it to <KOReader settings dir>/simpleui/sui_quotes/
then set Source → Custom on the module

