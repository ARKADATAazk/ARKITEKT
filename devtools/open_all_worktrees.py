#!/usr/bin/env python3
"""Open all ARKITEKT-Dev worktree folders in VS Code.

Includes delay between launches for Stardock Groupy compatibility.
"""

import subprocess
import time
from pathlib import Path

SCRIPTS_DIR = Path(r'D:\Dropbox\REAPER\Scripts')
PREFIX = 'ARKITEKT-Dev'
LAUNCH_DELAY = 2.0  # seconds between VS Code launches (for Groupy)

def main():
    folders = sorted(
        p for p in SCRIPTS_DIR.iterdir()
        if p.is_dir() and p.name.startswith(PREFIX)
    )

    if not folders:
        print(f'No folders matching {PREFIX}* found in {SCRIPTS_DIR}')
        return

    print(f'Opening {len(folders)} worktree(s) in VS Code:')
    for i, folder in enumerate(folders):
        print(f'  - {folder.name}')
        subprocess.Popen(['code', str(folder)], shell=True)

        # Delay between launches for Groupy to detect and apply rules
        if i < len(folders) - 1:
            time.sleep(LAUNCH_DELAY)

if __name__ == '__main__':
    main()
