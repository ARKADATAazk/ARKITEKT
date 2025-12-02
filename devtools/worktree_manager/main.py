"""
ARKITEKT Worktree Manager
PySide6 tool for managing git worktrees from folder structure.
"""

import sys
import os
import subprocess
import json
from pathlib import Path
from typing import Optional

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTreeView, QLineEdit, QPushButton, QLabel, QListWidget, QListWidgetItem,
    QSplitter, QGroupBox, QMessageBox, QFileSystemModel, QFrame,
    QComboBox, QStyle, QMenu, QTabWidget, QTableWidget, QTableWidgetItem,
    QHeaderView, QAbstractItemView, QProgressDialog
)
from PySide6.QtCore import Qt, QDir, QModelIndex, QSettings, QByteArray, QThread, QObject, Signal, QMimeData
from PySide6.QtGui import QFont, QPalette, QColor, QAction, QDrag


class DraggableWorktreeList(QListWidget):
    """Custom QListWidget with drag-and-drop support for merging branches."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setDragEnabled(True)
        self.setAcceptDrops(True)
        self.setDropIndicatorShown(True)
        self.setDragDropMode(QAbstractItemView.DragDropMode.DragDrop)
        self.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.setDefaultDropAction(Qt.DropAction.MoveAction)

    def startDrag(self, supportedActions):
        """Start drag operation with selected worktree(s)."""
        selected_items = self.selectedItems()
        if not selected_items:
            return

        # Get branch names and paths from selected items
        drag_data = []
        for item in selected_items:
            data = item.data(Qt.ItemDataRole.UserRole)
            if data:
                drag_data.append(data)

        if not drag_data:
            return

        # Create drag with mime data
        drag = QDrag(self)
        mime_data = QMimeData()

        # Store as JSON string
        import json
        mime_data.setText(json.dumps(drag_data))
        drag.setMimeData(mime_data)

        # Execute drag (Qt will use default cursor)
        drag.exec(Qt.DropAction.MoveAction)

    def dragEnterEvent(self, event):
        """Accept drag if it contains worktree data."""
        if event.mimeData().hasText():
            event.acceptProposedAction()
        else:
            event.ignore()

    def dragMoveEvent(self, event):
        """Show where drop would occur."""
        if event.mimeData().hasText():
            event.acceptProposedAction()
        else:
            event.ignore()

    def dropEvent(self, event):
        """Handle drop - merge dragged branch(es) into target."""
        if not event.mimeData().hasText():
            event.ignore()
            return

        # Get drop target item
        target_item = self.itemAt(event.position().toPoint())
        if not target_item:
            event.ignore()
            return

        target_data = target_item.data(Qt.ItemDataRole.UserRole)
        if not target_data:
            event.ignore()
            return

        # Get dragged items data
        import json
        try:
            dragged_data = json.loads(event.mimeData().text())
        except Exception:
            event.ignore()
            return

        # Don't allow dropping onto self
        if target_data in dragged_data:
            event.ignore()
            return

        event.acceptProposedAction()

        # Find the main window (navigate up parent chain)
        main_window = self
        while main_window and not hasattr(main_window, '_handle_merge_drop'):
            main_window = main_window.parent()

        if main_window and hasattr(main_window, '_handle_merge_drop'):
            main_window._handle_merge_drop(dragged_data, target_data)


class NumericTableWidgetItem(QTableWidgetItem):
    """Custom table item that sorts by numeric value instead of text."""
    def __init__(self, text, sort_value):
        super().__init__(text)
        self._sort_value = sort_value

    def __lt__(self, other):
        if isinstance(other, NumericTableWidgetItem):
            return self._sort_value < other._sort_value
        return super().__lt__(other)


class BranchDeleteWorker(QObject):
    """Worker for deleting branches in background thread."""

    # Signals
    progress = Signal(int, int, str)  # current, total, message
    finished = Signal(list)  # failed deletions
    confirmation_needed = Signal(str, str)  # branch_name, reason
    confirmation_result = Signal(bool)  # user's answer

    def __init__(self, repo_root, branches_to_delete):
        super().__init__()
        self.repo_root = repo_root
        self.branches_to_delete = branches_to_delete
        self.cancelled = False
        self.failed = []
        self._confirmation_response = None

    def cancel(self):
        """Request cancellation."""
        self.cancelled = True

    def set_confirmation_response(self, response: bool):
        """Set the user's response to confirmation dialog."""
        self._confirmation_response = response

    def run(self):
        """Execute branch deletions."""
        self.failed = []

        for i, (branch_name, del_type) in enumerate(self.branches_to_delete):
            if self.cancelled:
                break

            self.progress.emit(i, len(self.branches_to_delete),
                             f"Deleting {branch_name} ({del_type})...")

            try:
                if del_type == "local" or del_type == "both":
                    result = subprocess.run(
                        ["git", "branch", "-d", branch_name],
                        capture_output=True, text=True, cwd=str(self.repo_root)
                    )

                    # If -d fails (unmerged), ask for confirmation
                    if result.returncode != 0 and "not fully merged" in result.stderr:
                        # Request confirmation from main thread
                        self._confirmation_response = None
                        self.confirmation_needed.emit(branch_name, "not fully merged")

                        # Wait for response (with timeout)
                        timeout = 30  # 30 seconds
                        while self._confirmation_response is None and timeout > 0:
                            QThread.msleep(100)
                            timeout -= 1
                            if self.cancelled:
                                break

                        if self._confirmation_response:
                            result = subprocess.run(
                                ["git", "branch", "-D", branch_name],
                                capture_output=True, text=True, cwd=str(self.repo_root)
                            )

                    if result.returncode != 0:
                        self.failed.append(f"{branch_name} (local): {result.stderr}")

                if del_type == "remote" or del_type == "both":
                    result = subprocess.run(
                        ["git", "push", "origin", "--delete", branch_name],
                        capture_output=True, text=True, cwd=str(self.repo_root)
                    )
                    if result.returncode != 0:
                        self.failed.append(f"{branch_name} (remote): {result.stderr}")

            except Exception as e:
                self.failed.append(f"{branch_name}: {e}")

        # Emit final progress
        self.progress.emit(len(self.branches_to_delete), len(self.branches_to_delete), "Done")
        self.finished.emit(self.failed)


# PyQt5 dark theme stylesheet (AMEO skin)
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

QTreeView, QListWidget {
    background-color: #181b1a;
    border: 1px solid #0A0E0D;
    border-radius: 2px;
    selection-background-color: #B0891E;
    selection-color: #ffffff;
    outline: none;
}

QTreeView::item, QListWidget::item {
    padding: 2px 4px;
    border-radius: 0px;
}

QTreeView::item:hover, QListWidget::item:hover {
    background-color: #2A3635;
}

QTreeView::item:selected, QListWidget::item:selected {
    background-color: #B0891E;
}

QTreeView::branch:has-children:closed {
    image: url(branch-closed.png);
}

QTreeView::branch:has-children:open {
    image: url(branch-open.png);
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

QComboBox::down-arrow {
    width: 12px;
    height: 12px;
}

QComboBox QAbstractItemView {
    background-color: #181b1a;
    border: 1px solid #0A0E0D;
    selection-background-color: #B0891E;
}

QMenu {
    background-color: #1A1D1D;
    border: 1px solid #0A0E0D;
    padding: 4px;
}

QMenu::item {
    padding: 6px 20px;
    border-radius: 2px;
}

QMenu::item:selected {
    background-color: #B0891E;
}

QMenu::separator {
    height: 1px;
    background-color: #273331;
    margin: 4px 0;
}

QTabWidget::pane {
    border: 1px solid #273331;
    border-radius: 0px;
    background-color: #1E2221;
}

QTabBar::tab {
    background-color: #242C2B;
    border: none;
    border-bottom: 2px solid transparent;
    padding: 6px 14px;
    margin-right: 0px;
    color: #999999;
    font-size: 8.5pt;
}

QTabBar::tab:selected {
    background-color: #1E2221;
    border-bottom: 2px solid #B0891E;
    color: #E0E0E0;
}

QTabBar::tab:hover {
    background-color: #2A3635;
    color: #BBBBBB;
}

QTableWidget {
    background-color: #181b1a;
    border: 1px solid #0A0E0D;
    border-radius: 0px;
    gridline-color: #273331;
    selection-background-color: #B0891E;
    selection-color: #ffffff;
}

QTableWidget::item {
    padding: 3px 6px;
}

QTableWidget::item:hover {
    background-color: #2A3635;
}

QTableWidget::item:selected {
    background-color: #B0891E;
    color: #ffffff;
}

QTableWidget::item:alternate {
    background-color: #1E2221;
}

QTableWidget::item:alternate:selected {
    background-color: #B0891E;
    color: #ffffff;
}

QHeaderView::section {
    background-color: #16191A;
    color: #E0E0E0;
    padding: 5px 6px;
    border: none;
    border-right: 1px solid #0A0E0D;
    border-bottom: 1px solid #0A0E0D;
    font-weight: 600;
    font-size: 8.5pt;
}

QHeaderView::section:hover {
    background-color: #242C2B;
}

QProgressDialog {
    background-color: #1E2221;
    color: #E0E0E0;
}

QProgressBar {
    border: 1px solid #273331;
    border-radius: 4px;
    background-color: #181b1a;
    text-align: center;
    color: #E0E0E0;
}

QProgressBar::chunk {
    background-color: #B0891E;
    border-radius: 3px;
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

QPushButton#dangerButton {
    background-color: #B0891E;
}

QPushButton#dangerButton:hover {
    background-color: #C99F36;
}

QPushButton#secondaryButton {
    background-color: #273331;
    border: 1px solid #1A2220;
}

QPushButton#secondaryButton:hover {
    background-color: #304341;
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

QSplitter::handle {
    background-color: #0A0E0D;
}

QSplitter::handle:horizontal {
    width: 2px;
}

QSplitter::handle:vertical {
    height: 2px;
}

QFrame#separator {
    background-color: #273331;
    max-height: 1px;
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


class WorktreeManager(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ARKITEKT Worktree Manager")
        self.setMinimumSize(1000, 700)

        # Detect repo root (where this script lives or parent)
        self.repo_root = self._find_repo_root()
        self.worktree_parent = self.repo_root.parent if self.repo_root else Path.cwd()

        # Settings file path
        self.settings_file = Path(__file__).parent / "settings.json"

        # Threading for branch operations
        self.delete_thread = None
        self.delete_worker = None
        self.delete_progress = None

        self._setup_ui()
        self._populate_branches()
        self._load_settings()
        self._refresh_worktrees()
        self._refresh_branches()

    def _find_repo_root(self) -> Optional[Path]:
        """Find the git repository root."""
        # Start from script location
        start = Path(__file__).resolve().parent
        current = start

        while current != current.parent:
            if (current / ".git").exists():
                return current
            current = current.parent

        # Fallback: try cwd
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                capture_output=True, text=True, cwd=str(start)
            )
            if result.returncode == 0:
                return Path(result.stdout.strip())
        except Exception:
            pass

        return None

    def _populate_branches(self):
        """Populate branch combo boxes with actual git branches."""
        if not self.repo_root:
            return

        try:
            # Get local branches
            result = subprocess.run(
                ["git", "branch", "--format=%(refname:short)"],
                capture_output=True, text=True, cwd=str(self.repo_root)
            )

            if result.returncode == 0:
                branches = [b.strip() for b in result.stdout.strip().split("\n") if b.strip()]

                # Populate base combo (for creating new worktrees)
                self.base_combo.clear()
                self.base_combo.addItems(branches)
                # Set default to dev or main
                for default in ["dev", "main"]:
                    if default in branches:
                        self.base_combo.setCurrentText(default)
                        break

                # Populate sync base combo (for rebasing)
                self.sync_base_combo.clear()
                self.sync_base_combo.addItems(branches)
                # Set default to dev or main
                for default in ["dev", "main"]:
                    if default in branches:
                        self.sync_base_combo.setCurrentText(default)
                        break

        except Exception as e:
            print(f"Failed to populate branches: {e}")

    def _setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(8, 8, 8, 8)
        main_layout.setSpacing(6)

        # Header
        header = QLabel("Worktree Manager")
        header.setObjectName("headerLabel")
        main_layout.addWidget(header)

        # Repo path display
        repo_label = QLabel(f"Repository: {self.repo_root or 'Not found'}")
        repo_label.setObjectName("pathLabel")
        main_layout.addWidget(repo_label)

        # Separator
        sep = QFrame()
        sep.setObjectName("separator")
        sep.setFrameShape(QFrame.Shape.HLine)
        main_layout.addWidget(sep)

        # Tab widget for different views
        self.tabs = QTabWidget()
        main_layout.addWidget(self.tabs, 1)

        # Tab 1: Worktree Manager
        worktree_tab = self._create_worktree_tab()
        self.tabs.addTab(worktree_tab, "Worktrees")

        # Tab 2: Branch Manager
        branch_tab = self._create_branch_tab()
        self.tabs.addTab(branch_tab, "Branches")

    def _create_worktree_tab(self) -> QWidget:
        """Create the worktree management tab."""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(0, 0, 0, 0)

        # Splitter for tree and worktree panels
        self.splitter = QSplitter(Qt.Orientation.Horizontal)
        layout.addWidget(self.splitter)

        # Left panel: Folder tree for branch naming
        left_panel = self._create_tree_panel()
        self.splitter.addWidget(left_panel)

        # Right panel: Worktree management
        right_panel = self._create_worktree_panel()
        self.splitter.addWidget(right_panel)

        self.splitter.setSizes([400, 600])

        return tab

    def _create_branch_tab(self) -> QWidget:
        """Create the branch management tab."""
        tab = QWidget()
        layout = QVBoxLayout(tab)
        layout.setContentsMargins(6, 6, 6, 6)
        layout.setSpacing(8)

        # Filter/search section
        filter_layout = QHBoxLayout()
        filter_layout.addWidget(QLabel("Show:"))

        self.branch_filter_combo = QComboBox()
        self.branch_filter_combo.addItems(["All", "Local Only", "Remote Only", "Merged", "Unmerged"])
        self.branch_filter_combo.currentTextChanged.connect(self._refresh_branches)
        filter_layout.addWidget(self.branch_filter_combo, 1)

        self.branch_search = QLineEdit()
        self.branch_search.setPlaceholderText("Search branches...")
        self.branch_search.textChanged.connect(self._filter_branch_table)
        filter_layout.addWidget(self.branch_search, 2)

        layout.addLayout(filter_layout)

        # Branch table
        self.branch_table = QTableWidget()
        self.branch_table.setColumnCount(6)
        self.branch_table.setHorizontalHeaderLabels([
            "Branch", "Type", "Last Commit", "Date", "Author", "Status"
        ])

        # Selection behavior
        self.branch_table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.branch_table.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.branch_table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)

        # Enable sorting
        self.branch_table.setSortingEnabled(True)

        # Enable alternating row colors for better readability
        self.branch_table.setAlternatingRowColors(True)

        # Enable column drag/drop reordering
        self.branch_table.horizontalHeader().setSectionsMovable(True)

        # Enable column resizing by dragging
        self.branch_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Interactive)
        self.branch_table.horizontalHeader().setStretchLastSection(True)

        # Enable context menu on headers (future: hide/show columns)
        self.branch_table.horizontalHeader().setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)

        # Show grid lines
        self.branch_table.setShowGrid(True)

        # Word wrap for long commit messages
        self.branch_table.setWordWrap(False)

        # Enable drag selection
        self.branch_table.setDragEnabled(False)  # We don't want to drag items out

        # Corner button behavior
        self.branch_table.setCornerButtonEnabled(True)

        self.branch_table.itemSelectionChanged.connect(self._on_branch_selection_changed)
        layout.addWidget(self.branch_table, 1)

        # Action buttons
        btn_layout = QHBoxLayout()

        refresh_branches_btn = QPushButton("Refresh")
        refresh_branches_btn.setObjectName("secondaryButton")
        refresh_branches_btn.clicked.connect(self._refresh_branches)
        btn_layout.addWidget(refresh_branches_btn)

        btn_layout.addStretch()

        self.delete_local_btn = QPushButton("Delete Local")
        self.delete_local_btn.setObjectName("dangerButton")
        self.delete_local_btn.clicked.connect(self._delete_local_branches)
        self.delete_local_btn.setEnabled(False)
        btn_layout.addWidget(self.delete_local_btn)

        self.delete_remote_btn = QPushButton("Delete Remote")
        self.delete_remote_btn.setObjectName("dangerButton")
        self.delete_remote_btn.clicked.connect(self._delete_remote_branches)
        self.delete_remote_btn.setEnabled(False)
        btn_layout.addWidget(self.delete_remote_btn)

        self.delete_both_btn = QPushButton("Delete Both")
        self.delete_both_btn.setObjectName("dangerButton")
        self.delete_both_btn.clicked.connect(self._delete_both_branches)
        self.delete_both_btn.setEnabled(False)
        btn_layout.addWidget(self.delete_both_btn)

        layout.addLayout(btn_layout)

        return tab

    def _create_tree_panel(self) -> QWidget:
        """Create the folder tree panel for branch name generation."""
        panel = QGroupBox("Folder Structure")
        layout = QVBoxLayout(panel)
        layout.setSpacing(6)
        layout.setContentsMargins(6, 10, 6, 6)

        # File system model (folders only)
        self.fs_model = QFileSystemModel()
        self.fs_model.setFilter(QDir.Filter.Dirs | QDir.Filter.NoDotAndDotDot)

        if self.repo_root:
            root_path = str(self.repo_root)
            self.fs_model.setRootPath(root_path)

        # Tree view
        self.tree_view = QTreeView()
        self.tree_view.setModel(self.fs_model)
        self.tree_view.setHeaderHidden(True)

        # Hide size, type, date columns
        for i in range(1, 4):
            self.tree_view.hideColumn(i)

        if self.repo_root:
            self.tree_view.setRootIndex(self.fs_model.index(str(self.repo_root)))

        self.tree_view.clicked.connect(self._on_tree_clicked)
        self.tree_view.expanded.connect(lambda: self._save_settings())  # Auto-save on expand
        self.tree_view.collapsed.connect(lambda: self._save_settings())  # Auto-save on collapse
        layout.addWidget(self.tree_view, 1)

        # Branch prefix selector
        prefix_layout = QHBoxLayout()
        prefix_layout.addWidget(QLabel("Prefix:"))
        self.prefix_combo = QComboBox()
        self.prefix_combo.addItems([
            "feature/", "phase/", "fix/", "refactor/", "experiment/", ""
        ])
        self.prefix_combo.setEditable(True)
        self.prefix_combo.currentTextChanged.connect(self._update_branch_preview)
        prefix_layout.addWidget(self.prefix_combo, 1)
        layout.addLayout(prefix_layout)

        # Generated branch name
        layout.addWidget(QLabel("Generated branch name:"))
        self.generated_branch = QLineEdit()
        self.generated_branch.setPlaceholderText("Click a folder or type custom name...")
        self.generated_branch.textChanged.connect(self._on_branch_name_changed)
        layout.addWidget(self.generated_branch)

        return panel

    def _create_worktree_panel(self) -> QWidget:
        """Create the worktree management panel."""
        panel = QGroupBox("Worktrees")
        layout = QVBoxLayout(panel)
        layout.setSpacing(8)
        layout.setContentsMargins(6, 10, 6, 6)

        # Existing worktrees list (with drag-and-drop support)
        self.worktree_list = DraggableWorktreeList(self)
        self.worktree_list.itemClicked.connect(self._on_worktree_selected)
        self.worktree_list.itemDoubleClicked.connect(self._on_worktree_double_clicked)
        self.worktree_list.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.worktree_list.customContextMenuRequested.connect(self._show_context_menu)
        layout.addWidget(self.worktree_list, 1)

        # Worktree actions
        action_layout = QHBoxLayout()

        refresh_btn = QPushButton("Refresh")
        refresh_btn.setObjectName("secondaryButton")
        refresh_btn.clicked.connect(self._refresh_worktrees)
        action_layout.addWidget(refresh_btn)

        self.remove_btn = QPushButton("Remove Selected")
        self.remove_btn.setObjectName("dangerButton")
        self.remove_btn.clicked.connect(self._remove_worktree)
        self.remove_btn.setEnabled(False)
        action_layout.addWidget(self.remove_btn)

        layout.addLayout(action_layout)

        # Separator
        sep = QFrame()
        sep.setObjectName("separator")
        sep.setFrameShape(QFrame.Shape.HLine)
        layout.addWidget(sep)

        # New worktree section
        layout.addWidget(QLabel("Create new worktree:"))

        # Branch name input
        branch_layout = QHBoxLayout()
        branch_layout.addWidget(QLabel("Branch:"))
        self.branch_input = QLineEdit()
        self.branch_input.setPlaceholderText("Branch name (from tree or custom)")
        branch_layout.addWidget(self.branch_input, 1)
        layout.addLayout(branch_layout)

        # Base branch selector
        base_layout = QHBoxLayout()
        base_layout.addWidget(QLabel("Base:"))
        self.base_combo = QComboBox()
        base_layout.addWidget(self.base_combo, 1)
        layout.addLayout(base_layout)

        # Worktree path preview
        layout.addWidget(QLabel("Worktree path:"))
        self.path_preview = QLineEdit()
        self.path_preview.setReadOnly(True)
        self.path_preview.setObjectName("pathLabel")
        layout.addWidget(self.path_preview)

        # Create button
        self.create_btn = QPushButton("Create Worktree")
        self.create_btn.clicked.connect(self._create_worktree)
        self.create_btn.setEnabled(False)
        layout.addWidget(self.create_btn)

        # Separator
        sep2 = QFrame()
        sep2.setObjectName("separator")
        sep2.setFrameShape(QFrame.Shape.HLine)
        layout.addWidget(sep2)

        # Git operations
        layout.addWidget(QLabel("Git operations:"))

        # Rebase section (prominent)
        rebase_layout = QHBoxLayout()
        rebase_layout.addWidget(QLabel("Update From (Rebase Onto):"))
        self.sync_base_combo = QComboBox()
        rebase_layout.addWidget(self.sync_base_combo, 1)

        self.sync_btn = QPushButton("Update")
        self.sync_btn.clicked.connect(self._sync_with_base)
        self.sync_btn.setEnabled(False)
        rebase_layout.addWidget(self.sync_btn)

        layout.addLayout(rebase_layout)

        # Other git operations dropdown
        other_ops_layout = QHBoxLayout()
        other_ops_layout.addWidget(QLabel("Other:"))

        self.git_ops_combo = QComboBox()
        self.git_ops_combo.addItems(["Select operation...", "Fetch All", "Pull (fast-forward)"])
        self.git_ops_combo.currentTextChanged.connect(self._on_git_op_selected)
        other_ops_layout.addWidget(self.git_ops_combo, 1)

        layout.addLayout(other_ops_layout)

        return panel

    def _load_settings(self):
        """Load persistent settings from JSON file."""
        if not self.settings_file.exists():
            return

        try:
            with open(self.settings_file, 'r') as f:
                settings = json.load(f)

            # Restore window geometry
            if 'window_geometry' in settings:
                geom = settings['window_geometry']
                self.setGeometry(geom['x'], geom['y'], geom['width'], geom['height'])

            # Restore splitter sizes
            if 'splitter_sizes' in settings:
                self.splitter.setSizes(settings['splitter_sizes'])

            # Restore prefix combo
            if 'prefix' in settings:
                idx = self.prefix_combo.findText(settings['prefix'])
                if idx >= 0:
                    self.prefix_combo.setCurrentIndex(idx)
                else:
                    self.prefix_combo.setCurrentText(settings['prefix'])

            # Restore base branch
            if 'base_branch' in settings:
                idx = self.base_combo.findText(settings['base_branch'])
                if idx >= 0:
                    self.base_combo.setCurrentIndex(idx)
                else:
                    self.base_combo.setCurrentText(settings['base_branch'])

            # Restore sync base branch
            if 'sync_base' in settings:
                idx = self.sync_base_combo.findText(settings['sync_base'])
                if idx >= 0:
                    self.sync_base_combo.setCurrentIndex(idx)
                else:
                    self.sync_base_combo.setCurrentText(settings['sync_base'])

            # Restore expanded tree paths
            if 'expanded_paths' in settings:
                for path in settings['expanded_paths']:
                    idx = self.fs_model.index(path)
                    if idx.isValid():
                        self.tree_view.setExpanded(idx, True)

            # Restore last selected folder
            if 'last_folder' in settings:
                idx = self.fs_model.index(settings['last_folder'])
                if idx.isValid():
                    self.tree_view.setCurrentIndex(idx)
                    self.tree_view.scrollTo(idx)

        except Exception as e:
            print(f"Failed to load settings: {e}")

    def _save_settings(self):
        """Save persistent settings to JSON file."""
        try:
            # Collect expanded paths
            expanded_paths = []
            def collect_expanded(parent_idx=None):
                if parent_idx is None:
                    parent_idx = self.tree_view.rootIndex()

                for row in range(self.fs_model.rowCount(parent_idx)):
                    idx = self.fs_model.index(row, 0, parent_idx)
                    if self.tree_view.isExpanded(idx):
                        path = self.fs_model.filePath(idx)
                        expanded_paths.append(path)
                        collect_expanded(idx)

            collect_expanded()

            # Get current selected folder
            current_idx = self.tree_view.currentIndex()
            last_folder = self.fs_model.filePath(current_idx) if current_idx.isValid() else None

            settings = {
                'window_geometry': {
                    'x': self.geometry().x(),
                    'y': self.geometry().y(),
                    'width': self.geometry().width(),
                    'height': self.geometry().height(),
                },
                'splitter_sizes': self.splitter.sizes(),
                'prefix': self.prefix_combo.currentText(),
                'base_branch': self.base_combo.currentText(),
                'sync_base': self.sync_base_combo.currentText(),
                'expanded_paths': expanded_paths,
                'last_folder': last_folder,
            }

            with open(self.settings_file, 'w') as f:
                json.dump(settings, f, indent=2)

        except Exception as e:
            print(f"Failed to save settings: {e}")

    def closeEvent(self, event):
        """Save settings and clean up threads before closing."""
        # Cancel any running deletion
        if self.delete_worker:
            self.delete_worker.cancel()

        # Wait for thread to finish (with timeout)
        if self.delete_thread and self.delete_thread.isRunning():
            self.delete_thread.quit()
            if not self.delete_thread.wait(3000):  # 3 second timeout
                self.delete_thread.terminate()

        self._save_settings()
        super().closeEvent(event)

    def _on_tree_clicked(self, index: QModelIndex):
        """Handle folder tree click - generate branch name from folder name."""
        path = Path(self.fs_model.filePath(index))
        # Use folder name only, preserve original capitalization
        branch_name = path.name.replace(" ", "-")
        self.generated_branch.setText(branch_name)

    def _update_branch_preview(self):
        """Update the branch name with current prefix."""
        self._on_branch_name_changed(self.generated_branch.text())

    def _on_branch_name_changed(self, text: str):
        """Update branch input and path preview when generated name changes."""
        if text:
            prefix = self.prefix_combo.currentText()
            full_branch = f"{prefix}{text}"
            self.branch_input.setText(full_branch)

            # Generate worktree path
            safe_name = full_branch.replace("/", "-")
            worktree_path = self.worktree_parent / f"ARKITEKT-Dev-{safe_name}"
            self.path_preview.setText(str(worktree_path))
            self.create_btn.setEnabled(True)
        else:
            self.branch_input.clear()
            self.path_preview.clear()
            self.create_btn.setEnabled(False)

    def _refresh_worktrees(self):
        """Refresh the list of existing worktrees."""
        self.worktree_list.clear()

        if not self.repo_root:
            return

        try:
            result = subprocess.run(
                ["git", "worktree", "list", "--porcelain"],
                capture_output=True, text=True, cwd=str(self.repo_root)
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split("\n")
                current_worktree = {}

                for line in lines:
                    if line.startswith("worktree "):
                        if current_worktree:
                            self._enrich_worktree_info(current_worktree)
                            self._add_worktree_item(current_worktree)
                        current_worktree = {"path": line[9:]}
                    elif line.startswith("HEAD "):
                        current_worktree["head"] = line[5:8]  # Short hash
                    elif line.startswith("branch "):
                        current_worktree["branch"] = line[7:].replace("refs/heads/", "")
                    elif line == "bare":
                        current_worktree["bare"] = True

                if current_worktree:
                    self._enrich_worktree_info(current_worktree)
                    self._add_worktree_item(current_worktree)

        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to list worktrees: {e}")

    def _enrich_worktree_info(self, info: dict):
        """Add git status information to worktree info."""
        path = info.get("path")
        if not path:
            return

        try:
            # Get last commit info
            result = subprocess.run(
                ["git", "log", "-1", "--format=%s|%ar|%an"],
                capture_output=True, text=True, cwd=path
            )
            if result.returncode == 0 and result.stdout.strip():
                parts = result.stdout.strip().split("|")
                if len(parts) == 3:
                    info["last_commit"] = {
                        "subject": parts[0][:50],  # Truncate long messages
                        "time": parts[1],
                        "author": parts[2]
                    }

            # Get ahead/behind status
            result = subprocess.run(
                ["git", "rev-list", "--left-right", "--count", "@{upstream}...HEAD"],
                capture_output=True, text=True, cwd=path
            )
            if result.returncode == 0 and result.stdout.strip():
                parts = result.stdout.strip().split()
                if len(parts) == 2:
                    behind, ahead = int(parts[0]), int(parts[1])
                    info["ahead_behind"] = {"ahead": ahead, "behind": behind}

            # Get dirty status
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                capture_output=True, text=True, cwd=path
            )
            if result.returncode == 0:
                info["dirty"] = bool(result.stdout.strip())

        except Exception:
            pass  # Silently ignore errors for individual worktrees

    def _add_worktree_item(self, info: dict):
        """Add a worktree to the list."""
        path = info.get("path", "")
        branch = info.get("branch", "detached")
        head = info.get("head", "")

        # Build display text
        display_parts = [branch]

        # Add ahead/behind indicators
        if "ahead_behind" in info:
            ab = info["ahead_behind"]
            if ab["ahead"] > 0 or ab["behind"] > 0:
                status = []
                if ab["ahead"] > 0:
                    status.append(f"↑{ab['ahead']}")
                if ab["behind"] > 0:
                    status.append(f"↓{ab['behind']}")
                display_parts.append(f"[{' '.join(status)}]")

        # Add dirty indicator
        if info.get("dirty"):
            display_parts.append("[*]")

        # Add last commit info
        if "last_commit" in info:
            commit = info["last_commit"]
            display_parts.append(f"• {commit['subject']}")
            display_parts.append(f"({commit['time']})")

        # Add worktree name
        is_main = path == str(self.repo_root)
        worktree_name = "main repo" if is_main else Path(path).name
        display = f"{display_parts[0]}  [{worktree_name}]\n    {' '.join(display_parts[1:])}"

        item = QListWidgetItem(display)
        item.setData(Qt.ItemDataRole.UserRole, path)

        # Build detailed tooltip
        tooltip_parts = [f"Path: {path}", f"Branch: {branch}"]
        if "last_commit" in info:
            commit = info["last_commit"]
            tooltip_parts.append(f"Last commit: {commit['subject']}")
            tooltip_parts.append(f"Author: {commit['author']}")
            tooltip_parts.append(f"Time: {commit['time']}")
        if "ahead_behind" in info:
            ab = info["ahead_behind"]
            tooltip_parts.append(f"Ahead: {ab['ahead']}, Behind: {ab['behind']}")
        if info.get("dirty"):
            tooltip_parts.append("Status: Uncommitted changes")

        item.setToolTip("\n".join(tooltip_parts))

        # Color coding
        if is_main:
            item.setForeground(QColor("#569cd6"))  # Blue for main
        elif info.get("dirty"):
            item.setForeground(QColor("#d7ba7d"))  # Yellow for dirty
        elif "ahead_behind" in info and (info["ahead_behind"]["ahead"] > 0 or info["ahead_behind"]["behind"] > 0):
            item.setForeground(QColor("#ce9178"))  # Orange for ahead/behind

        self.worktree_list.addItem(item)

    def _on_worktree_selected(self, item: QListWidgetItem):
        """Handle worktree selection."""
        path = item.data(Qt.ItemDataRole.UserRole)
        is_main = path == str(self.repo_root)

        self.remove_btn.setEnabled(not is_main)
        self.sync_btn.setEnabled(True)

    def _on_worktree_double_clicked(self, item: QListWidgetItem):
        """Handle double-click on worktree - open in VS Code."""
        self._open_in_vscode()

    def _show_context_menu(self, position):
        """Show context menu for worktree list."""
        item = self.worktree_list.itemAt(position)
        if not item:
            return

        menu = QMenu(self)

        # Git operations section
        rebase_action = QAction("Rebase from...", self)
        rebase_action.triggered.connect(self._rebase_worktree)
        menu.addAction(rebase_action)

        menu.addSeparator()

        # Open operations section
        open_vscode_action = QAction("Open in VS Code", self)
        open_vscode_action.triggered.connect(self._open_in_vscode)
        menu.addAction(open_vscode_action)

        open_explorer_action = QAction("Open in Explorer", self)
        open_explorer_action.triggered.connect(self._open_in_explorer)
        menu.addAction(open_explorer_action)

        menu.exec(self.worktree_list.mapToGlobal(position))

    def _on_git_op_selected(self, text: str):
        """Handle selection from git operations dropdown."""
        if text == "Fetch All":
            self._fetch_all()
            self.git_ops_combo.setCurrentIndex(0)  # Reset to "Select operation..."
        elif text == "Pull (fast-forward)":
            self._pull_worktree()
            self.git_ops_combo.setCurrentIndex(0)

    def _create_worktree(self):
        """Create a new worktree."""
        branch = self.branch_input.text().strip()
        base = self.base_combo.currentText().strip()
        path = self.path_preview.text().strip()

        if not branch or not path:
            QMessageBox.warning(self, "Error", "Branch name and path are required.")
            return

        if Path(path).exists():
            QMessageBox.warning(self, "Error", f"Path already exists: {path}")
            return

        try:
            # Create worktree with new branch
            result = subprocess.run(
                ["git", "worktree", "add", "-b", branch, path, base],
                capture_output=True, text=True, cwd=str(self.repo_root)
            )

            if result.returncode == 0:
                QMessageBox.information(
                    self, "Success",
                    f"Created worktree:\n{path}\n\nBranch: {branch}\nBase: {base}"
                )
                self._refresh_worktrees()
                self.generated_branch.clear()
            else:
                # Maybe branch exists, try without -b
                result2 = subprocess.run(
                    ["git", "worktree", "add", path, branch],
                    capture_output=True, text=True, cwd=str(self.repo_root)
                )

                if result2.returncode == 0:
                    QMessageBox.information(
                        self, "Success",
                        f"Created worktree using existing branch:\n{path}\n\nBranch: {branch}"
                    )
                    self._refresh_worktrees()
                    self.generated_branch.clear()
                else:
                    QMessageBox.critical(
                        self, "Error",
                        f"Failed to create worktree:\n{result.stderr}\n{result2.stderr}"
                    )

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to create worktree: {e}")

    def _remove_worktree(self):
        """Remove the selected worktree."""
        item = self.worktree_list.currentItem()
        if not item:
            return

        path = item.data(Qt.ItemDataRole.UserRole)

        reply = QMessageBox.question(
            self, "Confirm Remove",
            f"Remove worktree?\n\n{path}\n\nThis will delete the folder!",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.Yes:
            try:
                result = subprocess.run(
                    ["git", "worktree", "remove", path, "--force"],
                    capture_output=True, text=True, cwd=str(self.repo_root)
                )

                if result.returncode == 0:
                    self._refresh_worktrees()
                else:
                    QMessageBox.critical(self, "Error", f"Failed: {result.stderr}")

            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed: {e}")

    def _fetch_all(self):
        """Fetch all remotes for all worktrees."""
        if not self.repo_root:
            return

        try:
            result = subprocess.run(
                ["git", "fetch", "--all", "--prune"],
                capture_output=True, text=True, cwd=str(self.repo_root)
            )

            if result.returncode == 0:
                QMessageBox.information(self, "Success", "Fetched all remotes successfully.")
                self._refresh_worktrees()
            else:
                QMessageBox.warning(self, "Error", f"Fetch failed:\n{result.stderr}")

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to fetch: {e}")

    def _pull_worktree(self):
        """Pull (fast-forward) the selected worktree."""
        item = self.worktree_list.currentItem()
        if not item:
            QMessageBox.warning(self, "No Selection", "Please select a worktree first.")
            return

        path = item.data(Qt.ItemDataRole.UserRole)

        # Check for uncommitted changes
        try:
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                capture_output=True, text=True, cwd=path
            )

            if result.stdout.strip():
                reply = QMessageBox.question(
                    self, "Uncommitted Changes",
                    "This worktree has uncommitted changes.\n\n"
                    "Pull anyway? (may fail if conflicts)",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
                )
                if reply == QMessageBox.StandardButton.No:
                    return

            # Try pull --ff-only (safe)
            result = subprocess.run(
                ["git", "pull", "--ff-only"],
                capture_output=True, text=True, cwd=path
            )

            if result.returncode == 0:
                QMessageBox.information(self, "Success", "Pulled successfully (fast-forward).")
                self._refresh_worktrees()
            else:
                QMessageBox.warning(
                    self, "Pull Failed",
                    f"Could not fast-forward pull:\n{result.stderr}\n\n"
                    "Use 'Rebase' button to sync with base branch instead."
                )

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to pull: {e}")

    def _sync_with_base(self):
        """Rebase the selected worktree onto a base branch."""
        item = self.worktree_list.currentItem()
        if not item:
            return

        path = item.data(Qt.ItemDataRole.UserRole)
        base_branch = self.sync_base_combo.currentText().strip()

        if not base_branch:
            QMessageBox.warning(self, "Error", "Please select a base branch.")
            return

        # Check for uncommitted changes
        try:
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                capture_output=True, text=True, cwd=path
            )

            if result.stdout.strip():
                QMessageBox.warning(
                    self, "Uncommitted Changes",
                    "This worktree has uncommitted changes.\n\n"
                    "Please commit or stash your changes before rebasing."
                )
                return

            # Get current branch name
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                capture_output=True, text=True, cwd=path
            )
            current_branch = result.stdout.strip()

            if not current_branch:
                QMessageBox.warning(self, "Error", "Could not determine current branch.")
                return

            # Confirm rebase
            reply = QMessageBox.question(
                self, "Confirm Rebase",
                f"Rebase '{current_branch}' onto '{base_branch}'?\n\n"
                "This will rewrite commit history.\n"
                "Make sure you haven't pushed this branch yet, or coordinate with your team.",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )

            if reply == QMessageBox.StandardButton.No:
                return

            # Fetch first
            subprocess.run(
                ["git", "fetch", "origin", base_branch],
                capture_output=True, text=True, cwd=path
            )

            # Rebase
            result = subprocess.run(
                ["git", "rebase", f"origin/{base_branch}"],
                capture_output=True, text=True, cwd=path
            )

            if result.returncode == 0:
                QMessageBox.information(
                    self, "Success",
                    f"Successfully rebased onto {base_branch}."
                )
                self._refresh_worktrees()
            else:
                QMessageBox.critical(
                    self, "Rebase Failed",
                    f"Rebase failed:\n{result.stderr}\n\n"
                    "You may need to resolve conflicts manually.\n"
                    f"Go to the worktree and run:\n  git rebase --abort\n"
                    "or resolve conflicts and:\n  git rebase --continue"
                )

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to rebase: {e}")

    def _open_in_explorer(self):
        """Open the selected worktree in file explorer."""
        item = self.worktree_list.currentItem()
        if not item:
            return

        path = item.data(Qt.ItemDataRole.UserRole)

        if sys.platform == "win32":
            os.startfile(path)
        elif sys.platform == "darwin":
            subprocess.run(["open", path])
        else:
            subprocess.run(["xdg-open", path])

    def _rebase_worktree(self):
        """Rebase selected worktree from a chosen branch."""
        item = self.worktree_list.currentItem()
        if not item:
            return

        worktree_path = item.data(Qt.ItemDataRole.UserRole)
        if not worktree_path:
            return

        # Get current branch
        try:
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                capture_output=True, text=True, cwd=worktree_path
            )
            current_branch = result.stdout.strip() if result.returncode == 0 else "unknown"
        except Exception:
            current_branch = "unknown"

        # Get list of branches for selection
        try:
            result = subprocess.run(
                ["git", "branch", "-a"],
                capture_output=True, text=True, cwd=worktree_path
            )
            branches = []
            if result.returncode == 0:
                for line in result.stdout.split("\n"):
                    line = line.strip()
                    if line and not line.startswith("*"):
                        # Remove remote prefix and clean up
                        branch = line.replace("remotes/origin/", "").replace("remotes/", "")
                        if branch and branch not in branches and "->" not in branch:
                            branches.append(branch)
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to list branches: {e}")
            return

        if not branches:
            QMessageBox.warning(self, "Error", "No branches found.")
            return

        # Show dialog to select rebase target
        from PySide6.QtWidgets import QInputDialog
        target_branch, ok = QInputDialog.getItem(
            self, "Rebase From",
            f"Rebase '{current_branch}' from which branch?",
            branches, 0, False
        )

        if not ok or not target_branch:
            return

        # Confirm rebase
        reply = QMessageBox.question(
            self, "Confirm Rebase",
            f"Rebase '{current_branch}' from '{target_branch}'?\n\n"
            f"Worktree: {worktree_path}\n\n"
            "This will rewrite commit history.\n"
            "If conflicts occur, you'll need to resolve them manually.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.No:
            return

        # Execute rebase
        try:
            result = subprocess.run(
                ["git", "rebase", target_branch],
                capture_output=True, text=True, cwd=worktree_path
            )

            if result.returncode != 0:
                if "CONFLICT" in result.stdout or "CONFLICT" in result.stderr:
                    QMessageBox.warning(
                        self, "Rebase Conflicts",
                        f"Conflicts detected during rebase!\n\n"
                        f"The rebase has been started but not completed.\n"
                        f"Open the worktree in VS Code to resolve conflicts:\n{worktree_path}\n\n"
                        f"After resolving:\n"
                        f"  git add <files>\n"
                        f"  git rebase --continue\n\n"
                        f"Or to abort:\n"
                        f"  git rebase --abort"
                    )
                else:
                    QMessageBox.critical(
                        self, "Rebase Failed",
                        f"Rebase failed:\n\n{result.stderr}"
                    )
            else:
                QMessageBox.information(
                    self, "Success",
                    f"Successfully rebased '{current_branch}' from '{target_branch}'!"
                )

            # Refresh worktree list
            self._refresh_worktrees()

        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to rebase: {e}")

    def _handle_merge_drop(self, dragged_data, target_data):
        """Handle merge operation from drag-and-drop."""
        # Get branch names
        source_branches = []
        for path in dragged_data:
            try:
                # Get branch name for this worktree
                result = subprocess.run(
                    ["git", "branch", "--show-current"],
                    capture_output=True, text=True, cwd=path
                )
                if result.returncode == 0 and result.stdout.strip():
                    branch = result.stdout.strip()
                    source_branches.append((branch, path))
            except Exception as e:
                print(f"Failed to get branch for {path}: {e}")

        if not source_branches:
            QMessageBox.warning(self, "Error", "Could not determine source branch(es).")
            return

        # Get target branch
        try:
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                capture_output=True, text=True, cwd=target_data
            )
            target_branch = result.stdout.strip() if result.returncode == 0 else "unknown"
        except Exception:
            target_branch = "unknown"

        # Confirm merge
        branch_list = "\n".join([f"  • {branch}" for branch, _ in source_branches])
        reply = QMessageBox.question(
            self, "Confirm Merge",
            f"Merge the following branch(es) into '{target_branch}'?\n\n{branch_list}\n\n"
            "This will switch to the target worktree and merge.\n"
            "If conflicts occur, you'll need to resolve them manually.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.No:
            return

        # Execute merges
        failed = []
        conflicts = []

        for source_branch, source_path in source_branches:
            try:
                # Merge in target worktree
                result = subprocess.run(
                    ["git", "merge", "--no-ff", source_branch, "-m",
                     f"Merge {source_branch} into {target_branch}"],
                    capture_output=True, text=True, cwd=target_data
                )

                if result.returncode != 0:
                    if "CONFLICT" in result.stdout or "CONFLICT" in result.stderr:
                        conflicts.append(source_branch)
                    else:
                        failed.append(f"{source_branch}: {result.stderr}")
            except Exception as e:
                failed.append(f"{source_branch}: {e}")

        # Show results
        if conflicts:
            QMessageBox.warning(
                self, "Merge Conflicts",
                f"Conflicts detected in:\n\n" + "\n".join([f"  • {b}" for b in conflicts]) +
                f"\n\nThe merge has been started but not completed.\n"
                f"Open the target worktree in VS Code to resolve conflicts:\n{target_data}\n\n"
                f"After resolving, commit the merge."
            )
        elif failed:
            QMessageBox.critical(
                self, "Merge Failed",
                "Some merges failed:\n\n" + "\n".join(failed)
            )
        else:
            QMessageBox.information(
                self, "Success",
                f"Successfully merged {len(source_branches)} branch(es) into {target_branch}!"
            )

        # Refresh worktree list
        self._refresh_worktrees()

    def _open_in_vscode(self):
        """Open the selected worktree in VS Code."""
        item = self.worktree_list.currentItem()
        if not item:
            return

        path = item.data(Qt.ItemDataRole.UserRole)

        # Try multiple methods to open VS Code
        methods = []

        # Method 1: 'code' command in PATH
        methods.append(["code", path])

        # Method 2: Windows - common installation paths
        if sys.platform == "win32":
            import os
            # User install
            user_code = os.path.expandvars(r"%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe")
            if os.path.exists(user_code):
                methods.insert(0, [user_code, path])

            # System install
            system_code = r"C:\Program Files\Microsoft VS Code\Code.exe"
            if os.path.exists(system_code):
                methods.insert(0, [system_code, path])

        # Try each method
        for method in methods:
            try:
                subprocess.Popen(method)
                return  # Success!
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue

        # All methods failed
        QMessageBox.warning(
            self, "VS Code Not Found",
            "Could not launch VS Code. Tried:\n"
            "• 'code' command in PATH\n"
            "• Common installation paths\n\n"
            "Please ensure VS Code is installed.\n\n"
            "To add 'code' to PATH: Open VS Code → Command Palette (Ctrl+Shift+P) → "
            "'Shell Command: Install code command in PATH'"
        )

    # ===== Branch Management Methods =====

    def _refresh_branches(self):
        """Refresh the branch table with current branches."""
        if not self.repo_root:
            return

        # Disable sorting while updating to avoid conflicts
        self.branch_table.setSortingEnabled(False)
        self.branch_table.setRowCount(0)
        filter_mode = self.branch_filter_combo.currentText()

        try:
            # Get local branches with info (get both unix timestamp and relative date)
            local_branches = {}
            result = subprocess.run(
                ["git", "for-each-ref", "--format=%(refname:short)|%(committerdate:unix)|%(committerdate:relative)|%(authorname)|%(subject)",
                 "refs/heads/"],
                capture_output=True, text=True, cwd=str(self.repo_root)
            )

            if result.returncode == 0:
                for line in result.stdout.strip().split("\n"):
                    if not line:
                        continue
                    parts = line.split("|", 4)
                    if len(parts) == 5:
                        branch, timestamp, date_relative, author, subject = parts
                        local_branches[branch] = {
                            "type": "local",
                            "timestamp": int(timestamp),
                            "date": date_relative,
                            "author": author,
                            "subject": subject[:50],
                            "merged": self._is_merged(branch)
                        }

            # Get remote branches
            remote_branches = {}
            result = subprocess.run(
                ["git", "for-each-ref", "--format=%(refname:short)|%(committerdate:unix)|%(committerdate:relative)|%(authorname)|%(subject)",
                 "refs/remotes/origin/"],
                capture_output=True, text=True, cwd=str(self.repo_root)
            )

            if result.returncode == 0:
                for line in result.stdout.strip().split("\n"):
                    if not line:
                        continue
                    parts = line.split("|", 4)
                    if len(parts) == 5:
                        full_name, timestamp, date_relative, author, subject = parts
                        # Strip "origin/" prefix
                        branch = full_name.replace("origin/", "")
                        if branch in local_branches:
                            local_branches[branch]["type"] = "both"
                        else:
                            remote_branches[branch] = {
                                "type": "remote",
                                "timestamp": int(timestamp),
                                "date": date_relative,
                                "author": author,
                                "subject": subject[:50],
                                "merged": False  # Remote-only branches
                            }

            # Get current branch
            result = subprocess.run(
                ["git", "branch", "--show-current"],
                capture_output=True, text=True, cwd=str(self.repo_root)
            )
            current_branch = result.stdout.strip() if result.returncode == 0 else ""

            # Get worktree branches
            worktree_branches = set()
            result = subprocess.run(
                ["git", "worktree", "list", "--porcelain"],
                capture_output=True, text=True, cwd=str(self.repo_root)
            )
            if result.returncode == 0:
                for line in result.stdout.strip().split("\n"):
                    if line.startswith("branch "):
                        branch = line[7:].replace("refs/heads/", "")
                        worktree_branches.add(branch)

            # Merge and populate table
            all_branches = {**local_branches, **remote_branches}

            for branch_name, info in sorted(all_branches.items()):
                # Apply filter
                if filter_mode == "Local Only" and info["type"] != "local" and info["type"] != "both":
                    continue
                if filter_mode == "Remote Only" and info["type"] != "remote":
                    continue
                if filter_mode == "Merged" and not info["merged"]:
                    continue
                if filter_mode == "Unmerged" and info["merged"]:
                    continue

                row = self.branch_table.rowCount()
                self.branch_table.insertRow(row)

                # Column 0: Branch name
                item = QTableWidgetItem(branch_name)
                if branch_name == current_branch:
                    item.setForeground(QColor("#569cd6"))  # Blue for current
                elif branch_name in worktree_branches:
                    item.setForeground(QColor("#4ec9b0"))  # Cyan for worktree
                self.branch_table.setItem(row, 0, item)

                # Column 1: Type
                type_text = {"local": "Local", "remote": "Remote", "both": "Both"}[info["type"]]
                item = QTableWidgetItem(type_text)
                if info["type"] == "both":
                    item.setForeground(QColor("#d7ba7d"))  # Yellow for both
                self.branch_table.setItem(row, 1, item)

                # Column 2: Last commit
                self.branch_table.setItem(row, 2, QTableWidgetItem(info["subject"]))

                # Column 3: Date (use timestamp for sorting, display relative)
                date_item = NumericTableWidgetItem(info["date"], info["timestamp"])
                self.branch_table.setItem(row, 3, date_item)

                # Column 4: Author
                self.branch_table.setItem(row, 4, QTableWidgetItem(info["author"]))

                # Column 5: Status
                status_parts = []
                if branch_name == current_branch:
                    status_parts.append("Current")
                if branch_name in worktree_branches and branch_name != current_branch:
                    status_parts.append("Worktree")
                if info["merged"]:
                    status_parts.append("Merged")
                if branch_name in ["main", "dev"]:
                    status_parts.append("Protected")

                status = ", ".join(status_parts) if status_parts else "-"
                item = QTableWidgetItem(status)
                if "Protected" in status:
                    item.setForeground(QColor("#f48771"))  # Red for protected
                self.branch_table.setItem(row, 5, item)

                # Store metadata
                self.branch_table.item(row, 0).setData(Qt.ItemDataRole.UserRole, {
                    "name": branch_name,
                    "type": info["type"],
                    "current": branch_name == current_branch,
                    "worktree": branch_name in worktree_branches,
                    "protected": branch_name in ["main", "dev"],
                    "merged": info["merged"]
                })

        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to refresh branches: {e}")

        # Re-enable sorting after all items are added
        self.branch_table.setSortingEnabled(True)

    def _is_merged(self, branch: str) -> bool:
        """Check if a branch is merged into main or dev."""
        if not self.repo_root:
            return False

        for base in ["main", "dev"]:
            try:
                result = subprocess.run(
                    ["git", "branch", "--merged", base],
                    capture_output=True, text=True, cwd=str(self.repo_root)
                )
                if result.returncode == 0:
                    merged = [b.strip().replace("* ", "") for b in result.stdout.strip().split("\n")]
                    if branch in merged:
                        return True
            except Exception:
                pass

        return False

    def _filter_branch_table(self):
        """Filter branch table based on search text."""
        search_text = self.branch_search.text().lower()

        for row in range(self.branch_table.rowCount()):
            branch_name = self.branch_table.item(row, 0).text().lower()
            should_show = search_text in branch_name
            self.branch_table.setRowHidden(row, not should_show)

    def _on_branch_selection_changed(self):
        """Update delete button states based on selection."""
        selected_rows = set(item.row() for item in self.branch_table.selectedItems())

        if not selected_rows:
            self.delete_local_btn.setEnabled(False)
            self.delete_remote_btn.setEnabled(False)
            self.delete_both_btn.setEnabled(False)
            return

        has_local = False
        has_remote = False
        has_both = False
        has_protected = False

        for row in selected_rows:
            data = self.branch_table.item(row, 0).data(Qt.ItemDataRole.UserRole)
            if data["protected"] or data["current"] or data["worktree"]:
                has_protected = True

            if data["type"] == "local":
                has_local = True
            elif data["type"] == "remote":
                has_remote = True
            elif data["type"] == "both":
                has_both = True

        # Enable buttons based on selection
        self.delete_local_btn.setEnabled((has_local or has_both) and not has_protected)
        self.delete_remote_btn.setEnabled((has_remote or has_both) and not has_protected)
        self.delete_both_btn.setEnabled(has_both and not has_protected)

    def _delete_local_branches(self):
        """Delete selected local branches."""
        self._delete_branches("local")

    def _delete_remote_branches(self):
        """Delete selected remote branches."""
        self._delete_branches("remote")

    def _delete_both_branches(self):
        """Delete selected branches from both local and remote."""
        self._delete_branches("both")

    def _delete_branches(self, delete_type: str):
        """Delete branches based on type (local/remote/both) using background thread."""
        selected_rows = set(item.row() for item in self.branch_table.selectedItems())

        if not selected_rows:
            return

        branches_to_delete = []
        protected_found = []

        for row in selected_rows:
            data = self.branch_table.item(row, 0).data(Qt.ItemDataRole.UserRole)
            branch_name = data["name"]
            branch_type = data["type"]

            # Hard block main/dev
            if branch_name in ["main", "dev"]:
                protected_found.append(f"{branch_name} (main/dev cannot be deleted)")
                continue

            # Block current branch
            if data["current"]:
                protected_found.append(f"{branch_name} (current branch)")
                continue

            # Block worktree branches
            if data["worktree"]:
                protected_found.append(f"{branch_name} (has active worktree)")
                continue

            # Filter by delete type
            if delete_type == "local" and branch_type in ["local", "both"]:
                branches_to_delete.append((branch_name, "local"))
            elif delete_type == "remote" and branch_type in ["remote", "both"]:
                branches_to_delete.append((branch_name, "remote"))
            elif delete_type == "both" and branch_type == "both":
                branches_to_delete.append((branch_name, "both"))

        if protected_found:
            QMessageBox.warning(
                self, "Protected Branches",
                "Cannot delete the following branches:\n\n" + "\n".join(protected_found)
            )

        if not branches_to_delete:
            return

        # Confirmation dialog
        branch_list = "\n".join([f"  - {name} ({typ})" for name, typ in branches_to_delete])
        reply = QMessageBox.question(
            self, "Confirm Delete",
            f"Delete {len(branches_to_delete)} branch(es)?\n\n{branch_list}\n\n"
            f"{'Remote deletions are PERMANENT!' if delete_type in ['remote', 'both'] else ''}",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )

        if reply == QMessageBox.StandardButton.No:
            return

        # Start deletion in background thread
        self._start_branch_deletion(branches_to_delete)

    def _start_branch_deletion(self, branches_to_delete):
        """Start branch deletion in background thread."""
        # Create progress dialog
        self.delete_progress = QProgressDialog("Starting deletion...", "Cancel", 0, len(branches_to_delete), self)
        self.delete_progress.setWindowTitle("Deleting Branches")
        self.delete_progress.setWindowModality(Qt.WindowModality.WindowModal)
        self.delete_progress.setMinimumDuration(0)
        self.delete_progress.setValue(0)
        self.delete_progress.canceled.connect(self._cancel_deletion)

        # Create worker and thread
        self.delete_thread = QThread()
        self.delete_worker = BranchDeleteWorker(self.repo_root, branches_to_delete)

        # Move worker to thread
        self.delete_worker.moveToThread(self.delete_thread)

        # Connect signals
        self.delete_thread.started.connect(self.delete_worker.run)
        self.delete_worker.progress.connect(self._update_deletion_progress)
        self.delete_worker.confirmation_needed.connect(self._handle_deletion_confirmation)
        self.delete_worker.finished.connect(self._deletion_finished)
        self.delete_worker.finished.connect(self.delete_thread.quit)
        self.delete_worker.finished.connect(self.delete_worker.deleteLater)
        self.delete_thread.finished.connect(self.delete_thread.deleteLater)

        # Start the thread
        self.delete_thread.start()

    def _update_deletion_progress(self, current: int, total: int, message: str):
        """Update progress dialog from worker thread."""
        if self.delete_progress:
            self.delete_progress.setLabelText(message)
            self.delete_progress.setValue(current)
            self.delete_progress.setMaximum(total)

    def _handle_deletion_confirmation(self, branch_name: str, reason: str):
        """Handle confirmation request from worker thread (unmerged branch)."""
        reply = QMessageBox.question(
            self, "Unmerged Branch",
            f"Branch '{branch_name}' is {reason}.\n\nForce delete?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )

        if self.delete_worker:
            self.delete_worker.set_confirmation_response(reply == QMessageBox.StandardButton.Yes)

    def _cancel_deletion(self):
        """Cancel the deletion operation."""
        if self.delete_worker:
            self.delete_worker.cancel()

    def _deletion_finished(self, failed: list):
        """Handle deletion completion."""
        # Close progress dialog
        if self.delete_progress:
            self.delete_progress.close()
            self.delete_progress = None

        # Show results
        if failed:
            QMessageBox.warning(
                self, "Deletion Errors",
                "Failed to delete some branches:\n\n" + "\n".join(failed)
            )
        else:
            QMessageBox.information(self, "Success", "All branches deleted successfully!")

        # Refresh everything
        self._refresh_branches()
        self._populate_branches()

        # Clean up
        self.delete_worker = None
        self.delete_thread = None


def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    app.setStyleSheet(DARK_STYLE)

    window = WorktreeManager()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
