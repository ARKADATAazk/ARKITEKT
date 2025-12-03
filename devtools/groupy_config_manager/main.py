"""
Groupy Config Manager
PySide6 tool for generating Stardock Groupy tab group configs for VS Code worktrees.
"""

import sys
from pathlib import Path

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QListWidget, QListWidgetItem,
    QGroupBox, QMessageBox, QFrame, QFileDialog,
    QCheckBox, QColorDialog
)
from PySide6.QtCore import Qt, QSize
from PySide6.QtGui import QColor, QIcon, QPixmap, QPainter, QBrush, QGuiApplication


# === Configuration ===
SCRIPTS_DIR = Path(r'D:\Dropbox\REAPER\Scripts')
PREFIX = 'ARKITEKT-Dev'
VSCODE_PATH = r'C:\Users\arkad\AppData\Local\Programs\Microsoft VS Code\Code.exe'


# Default colors for known worktrees (by suffix after ARKITEKT-Dev-)
# Stored as RGB hex strings
DEFAULT_COLORS = {
    '': '#FF0000',              # Main ARKITEKT-Dev - Red
    'ItemPicker': '#FF8000',    # Orange
    'Optimization': '#FFFF00',  # Yellow
    'TemplateBrowser': '#00FF00',  # Lime
    'regionplaylist': '#00FFFF',   # Cyan
    'ThemeManager': '#800080',     # Purple
    'Staging': '#FFC0CB',          # Pink
    'Widgets': '#008000',          # Green
    'ThemeAdjuster': '#FF00FF',    # Magenta
}


# Dark theme stylesheet (matching worktree_manager)
DARK_STYLE = """
QMainWindow, QWidget {
    background-color: #1E2221;
    color: #BBBBBB;
    font-family: 'Segoe UI', Arial, sans-serif;
    font-size: 9pt;
}

QGroupBox {
    border: 1px solid #273331;
    border-radius: 2px;
    margin-top: 8px;
    padding-top: 6px;
    font-weight: 600;
    font-size: 8.5pt;
    color: #B0891E;
}

QGroupBox::title {
    subcontrol-origin: margin;
    left: 8px;
    padding: 0 4px;
}

QListWidget {
    background-color: #181b1a;
    border: 1px solid #0A0E0D;
    border-radius: 2px;
    selection-background-color: #B0891E;
    selection-color: #ffffff;
    outline: none;
}

QListWidget::item {
    padding: 2px 4px;
    border-radius: 0px;
}

QListWidget::item:hover {
    background-color: #2A3635;
}

QListWidget::item:selected {
    background-color: #B0891E;
}

QLineEdit, QComboBox {
    background-color: #242C2B;
    border: 1px solid #273331;
    border-radius: 2px;
    padding: 4px 8px;
    color: #E0E0E0;
    selection-background-color: #B0891E;
}

QLineEdit:focus, QComboBox:focus {
    border: 1px solid #B0891E;
    background-color: #1A1D1D;
}

QComboBox::drop-down {
    border: none;
    padding-right: 8px;
}

QComboBox QAbstractItemView {
    background-color: #181b1a;
    border: 1px solid #0A0E0D;
    selection-background-color: #B0891E;
}

QTextEdit {
    background-color: #181b1a;
    border: 1px solid #0A0E0D;
    border-radius: 2px;
    color: #E0E0E0;
    font-family: 'Consolas', 'Courier New', monospace;
    font-size: 8pt;
}

QPushButton {
    background-color: #B0891E;
    border: none;
    border-radius: 2px;
    padding: 5px 12px;
    color: #ffffff;
    font-weight: 500;
    min-width: 60px;
    font-size: 9pt;
}

QPushButton:hover {
    background-color: #C99F36;
}

QPushButton:pressed {
    background-color: #8E6D14;
}

QPushButton:disabled {
    background-color: #273331;
    color: #666666;
}

QPushButton#secondaryButton {
    background-color: #273331;
    border: 1px solid #1A2220;
}

QPushButton#secondaryButton:hover {
    background-color: #304341;
}

QPushButton#colorButton {
    min-width: 24px;
    max-width: 24px;
    min-height: 24px;
    max-height: 24px;
    padding: 0;
    border-radius: 2px;
}

QLabel {
    color: #BBBBBB;
    font-size: 8.5pt;
}

QLabel#headerLabel {
    font-size: 11pt;
    font-weight: 600;
    color: #B0891E;
    padding: 4px 0;
}

QLabel#pathLabel {
    color: #999999;
    font-size: 8pt;
}

QFrame#separator {
    background-color: #273331;
    max-height: 1px;
}

QCheckBox {
    color: #BBBBBB;
    spacing: 6px;
}

QCheckBox::indicator {
    width: 16px;
    height: 16px;
    border: 1px solid #273331;
    border-radius: 2px;
    background-color: #242C2B;
}

QCheckBox::indicator:checked {
    background-color: #B0891E;
    border-color: #B0891E;
}

QCheckBox::indicator:hover {
    border-color: #B0891E;
}

QSplitter::handle {
    background-color: #0A0E0D;
}

QSplitter::handle:horizontal {
    width: 2px;
}

QSplitter::handle:vertical {
    height: 2px;
}

QScrollBar:vertical {
    background-color: #1E2221;
    width: 12px;
    border: none;
}

QScrollBar::handle:vertical {
    background-color: #273331;
    border-radius: 4px;
    min-height: 30px;
    margin: 2px;
}

QScrollBar::handle:vertical:hover {
    background-color: #304341;
}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
    height: 0;
}

QScrollBar:horizontal {
    background-color: #1E2221;
    height: 12px;
    border: none;
}

QScrollBar::handle:horizontal {
    background-color: #273331;
    border-radius: 4px;
    min-width: 30px;
    margin: 2px;
}

QScrollBar::handle:horizontal:hover {
    background-color: #304341;
}

QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {
    width: 0;
}
"""


def create_color_icon(color_hex: str, size: int = 16) -> QIcon:
    """Create a solid color icon."""
    pixmap = QPixmap(size, size)
    pixmap.fill(Qt.GlobalColor.transparent)
    painter = QPainter(pixmap)
    painter.setBrush(QBrush(QColor(color_hex)))
    painter.setPen(Qt.PenStyle.NoPen)
    painter.drawRoundedRect(0, 0, size, size, 2, 2)
    painter.end()
    return QIcon(pixmap)


def rgb_to_bgr(hex_color: str) -> int:
    """Convert RGB hex string to BGR int for Groupy."""
    # Remove # if present
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return (b << 16) | (g << 8) | r


class WorktreeEntry:
    """Represents a worktree entry for the config."""
    def __init__(self, path: Path, enabled: bool = True, color_hex: str = '#808080'):
        self.path = path
        self.enabled = enabled
        self.color_hex = color_hex  # RGB hex string like '#FF0000'

    @property
    def folder_name(self) -> str:
        """Full folder name."""
        return self.path.name

    @property
    def display_name(self) -> str:
        """Display name (without ARKITEKT-Dev- prefix unless it's just ARKITEKT-Dev)."""
        name = self.path.name
        if name == PREFIX:
            return name  # Keep full name for main
        elif name.startswith(PREFIX + '-'):
            return name[len(PREFIX) + 1:]  # Remove prefix
        return name

    @property
    def suffix(self) -> str:
        """Get the suffix after ARKITEKT-Dev- (or empty for main)."""
        name = self.path.name
        if name == PREFIX:
            return ''
        elif name.startswith(PREFIX + '-'):
            return name[len(PREFIX) + 1:]
        return name

    @property
    def color_bgr(self) -> int:
        """Get the BGR color value for Groupy."""
        return rgb_to_bgr(self.color_hex)


class GroupyConfigManager(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Groupy Config Manager")
        self.setMinimumSize(700, 500)

        self.scripts_dir = SCRIPTS_DIR
        self.entries: list[WorktreeEntry] = []

        self._setup_ui()
        self._scan_worktrees()

    def _setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(8, 8, 8, 8)
        main_layout.setSpacing(6)

        # Header
        header = QLabel("Groupy Config Manager")
        header.setObjectName("headerLabel")
        main_layout.addWidget(header)

        # Path display and change button
        path_layout = QHBoxLayout()
        self.path_label = QLabel(f"Scanning: {self.scripts_dir}")
        self.path_label.setObjectName("pathLabel")
        path_layout.addWidget(self.path_label, 1)

        change_path_btn = QPushButton("Change")
        change_path_btn.setObjectName("secondaryButton")
        change_path_btn.setFixedWidth(60)
        change_path_btn.clicked.connect(self._change_path)
        path_layout.addWidget(change_path_btn)
        main_layout.addLayout(path_layout)

        # Separator
        sep = QFrame()
        sep.setObjectName("separator")
        sep.setFrameShape(QFrame.Shape.HLine)
        main_layout.addWidget(sep)

        # Main content: worktree list
        content_group = QGroupBox("Worktrees")
        content_layout = QVBoxLayout(content_group)

        # Worktree list
        self.worktree_list = QListWidget()
        self.worktree_list.setSelectionMode(QListWidget.SelectionMode.ExtendedSelection)
        content_layout.addWidget(self.worktree_list, 1)

        # Quick actions
        quick_layout = QHBoxLayout()

        select_all_btn = QPushButton("Select All")
        select_all_btn.setObjectName("secondaryButton")
        select_all_btn.clicked.connect(self._select_all)
        quick_layout.addWidget(select_all_btn)

        select_none_btn = QPushButton("Select None")
        select_none_btn.setObjectName("secondaryButton")
        select_none_btn.clicked.connect(self._select_none)
        quick_layout.addWidget(select_none_btn)

        quick_layout.addStretch()

        refresh_btn = QPushButton("Refresh")
        refresh_btn.setObjectName("secondaryButton")
        refresh_btn.clicked.connect(self._scan_worktrees)
        quick_layout.addWidget(refresh_btn)

        content_layout.addLayout(quick_layout)
        main_layout.addWidget(content_group, 1)

        # Generate button
        generate_btn = QPushButton("Copy Config to Clipboard")
        generate_btn.clicked.connect(self._generate_config)
        main_layout.addWidget(generate_btn)

    def _scan_worktrees(self):
        """Scan for worktrees and populate the list."""
        self.entries.clear()
        self.worktree_list.clear()

        if not self.scripts_dir.exists():
            QMessageBox.warning(self, "Error", f"Directory not found: {self.scripts_dir}")
            return

        folders = sorted(
            p for p in self.scripts_dir.iterdir()
            if p.is_dir() and p.name.startswith(PREFIX)
        )

        for folder in folders:
            # Determine default color
            suffix = folder.name[len(PREFIX) + 1:] if folder.name != PREFIX else ''
            default_color = DEFAULT_COLORS.get(suffix, '#808080')

            entry = WorktreeEntry(folder, enabled=True, color_hex=default_color)
            self.entries.append(entry)
            self._add_worktree_item(entry)

        if not folders:
            QMessageBox.information(
                self, "No Worktrees",
                f"No folders matching '{PREFIX}*' found in:\n{self.scripts_dir}"
            )

    def _add_worktree_item(self, entry: WorktreeEntry):
        """Add a worktree entry to the list."""
        item = QListWidgetItem()
        item.setSizeHint(QSize(0, 36))

        # Create custom widget
        widget = QWidget()
        layout = QHBoxLayout(widget)
        layout.setContentsMargins(4, 2, 4, 2)
        layout.setSpacing(8)

        # Checkbox for enable/disable
        checkbox = QCheckBox()
        checkbox.setChecked(entry.enabled)
        checkbox.stateChanged.connect(lambda state, e=entry: self._on_checkbox_changed(e, state))
        layout.addWidget(checkbox)

        # Color button
        color_btn = QPushButton()
        color_btn.setObjectName("colorButton")
        color_btn.setIcon(create_color_icon(entry.color_hex, 20))
        color_btn.setToolTip(f"Color: {entry.color_hex}")
        color_btn.clicked.connect(lambda checked, e=entry, b=color_btn: self._pick_color(e, b))
        layout.addWidget(color_btn)

        # Worktree name (display name without prefix)
        name_label = QLabel(entry.display_name)
        name_label.setStyleSheet("font-weight: 500;")
        layout.addWidget(name_label, 1)

        # Store references for later updates
        item.setData(Qt.ItemDataRole.UserRole, {
            'entry': entry,
            'checkbox': checkbox,
            'color_btn': color_btn,
        })

        self.worktree_list.addItem(item)
        self.worktree_list.setItemWidget(item, widget)

    def _on_checkbox_changed(self, entry: WorktreeEntry, state: int):
        """Handle checkbox state change."""
        entry.enabled = state == Qt.CheckState.Checked.value

    def _pick_color(self, entry: WorktreeEntry, button: QPushButton):
        """Show color picker for entry."""
        initial_color = QColor(entry.color_hex)
        color = QColorDialog.getColor(initial_color, self, "Select Color")

        if color.isValid():
            entry.color_hex = color.name()  # Returns '#rrggbb'
            button.setIcon(create_color_icon(entry.color_hex, 20))
            button.setToolTip(f"Color: {entry.color_hex}")

    def _select_all(self):
        """Enable all worktrees."""
        for i in range(self.worktree_list.count()):
            item = self.worktree_list.item(i)
            data = item.data(Qt.ItemDataRole.UserRole)
            if data:
                data['entry'].enabled = True
                data['checkbox'].setChecked(True)

    def _select_none(self):
        """Disable all worktrees."""
        for i in range(self.worktree_list.count()):
            item = self.worktree_list.item(i)
            data = item.data(Qt.ItemDataRole.UserRole)
            if data:
                data['entry'].enabled = False
                data['checkbox'].setChecked(False)

    def _change_path(self):
        """Change the scripts directory."""
        path = QFileDialog.getExistingDirectory(
            self, "Select Scripts Directory", str(self.scripts_dir)
        )
        if path:
            self.scripts_dir = Path(path)
            self.path_label.setText(f"Scanning: {self.scripts_dir}")
            self._scan_worktrees()

    def _generate_config(self):
        """Generate the Groupy config and copy to clipboard."""
        enabled_entries = [e for e in self.entries if e.enabled]

        if not enabled_entries:
            QMessageBox.warning(self, "No Selection", "Please select at least one worktree.")
            return

        # Build config content
        lines = [
            '[Group]',
            f'GroupCount={len(enabled_entries)}',
            'GroupLeft=370',
            'GroupTop=-975',
            'GroupRight=1810',
            'GroupBottom=-75',
            'GroupMax=1',
            f'LiveIndex={len(enabled_entries)}',
            'Locked=0',
        ]

        for i, entry in enumerate(enabled_entries, 1):
            lines.extend([
                f'[GroupyEntry{i}]',
                f'OwnerProcess={VSCODE_PATH}',
                'APPID=Microsoft.VisualStudioCode',
                f'NewTabName={entry.display_name}',
                'RunElevated=0',
                f'SavedColour={entry.color_bgr}',
                'NoPatternMatching=0',
                f'CommandLine="{entry.path}"',
                f'WorkingDirectory={entry.path}',
                f'Target={VSCODE_PATH}',
                'MatchingClass=Chrome_WidgetWin_1',
            ])

        config_content = '\n'.join(lines)

        # Copy to clipboard
        clipboard = QGuiApplication.clipboard()
        clipboard.setText(config_content)

        QMessageBox.information(
            self, "Copied",
            f"Config with {len(enabled_entries)} entries copied to clipboard.\n\n"
            "Paste into a .grp file to use with Groupy."
        )


def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setStyleSheet(DARK_STYLE)

    window = GroupyConfigManager()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
