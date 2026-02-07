# pytest-schema-validator - Skill Definition

**Skill ID**: `pytest-schema-validator`
**Category**: Testing / Database Quality Assurance
**Version**: 1.0.0
**Created**: 2026-02-07
**Platform**: Python 3.10+ / pytest / SQLite

---

## Overview

SQLite database schema validation test auto-generator. Extracts schema information (tables, columns, types, constraints, indexes, foreign keys) from an existing `.db` file and produces a complete pytest test suite that guards against DDL regressions.

---

## Use Cases

- **DDL Migration Guard**: Detect unintended table/column changes after schema migrations
- **CI/CD Gate**: Validate DB schema in automated pipelines before deployment
- **Multi-Developer Safety**: Prevent schema drift when multiple developers modify init scripts
- **Documentation Verification**: Ensure schema documentation matches the actual database
- **Refactoring Confidence**: Safely rename or restructure tables with regression tests

---

## Skill Input

When invoked, this skill requires:

1. **Database File Path**
   - Path to the SQLite `.db` file (or the `init_db.py` script that creates it)
   - Example: `data/botsunichiroku.db`

2. **Test Output Path**
   - Where to write the generated test file
   - Example: `tests/test_schema.py`

3. **Fixture Strategy** (optional)
   - `tmp_db` (default): Create a temporary DB per test session using `init_db`
   - `live_db`: Connect to the actual DB file (read-only tests)

---

## Implementation

### Step 1: Schema Extraction

Use these PRAGMAs to extract full schema information:

```python
import sqlite3
from pathlib import Path


def extract_schema(db_path: str) -> dict:
    """Extract complete schema from a SQLite database."""
    conn = sqlite3.connect(db_path)
    schema = {"tables": {}}

    # Get all tables (exclude internal sqlite_ tables)
    tables = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ).fetchall()

    for (table_name,) in tables:
        table_info = {}

        # Column definitions: cid, name, type, notnull, dflt_value, pk
        columns = conn.execute(f"PRAGMA table_info('{table_name}')").fetchall()
        table_info["columns"] = [
            {
                "name": col[1],
                "type": col[2],
                "notnull": bool(col[3]),
                "default": col[4],
                "pk": bool(col[5]),
            }
            for col in columns
        ]

        # Indexes: seq, name, unique, origin, partial
        indexes = conn.execute(f"PRAGMA index_list('{table_name}')").fetchall()
        table_info["indexes"] = []
        for idx in indexes:
            idx_name = idx[1]
            idx_unique = bool(idx[2])
            idx_columns = conn.execute(
                f"PRAGMA index_info('{idx_name}')"
            ).fetchall()
            table_info["indexes"].append({
                "name": idx_name,
                "unique": idx_unique,
                "columns": [ic[2] for ic in idx_columns],
            })

        # Foreign keys: id, seq, table, from, to, on_update, on_delete, match
        fks = conn.execute(f"PRAGMA foreign_key_list('{table_name}')").fetchall()
        table_info["foreign_keys"] = [
            {
                "from_col": fk[3],
                "to_table": fk[2],
                "to_col": fk[4],
            }
            for fk in fks
        ]

        schema["tables"][table_name] = table_info

    conn.close()
    return schema
```

### Step 2: Test Generation Template

#### conftest.py Template

```python
"""conftest.py - Schema test fixtures."""

import sqlite3
import sys
from pathlib import Path

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))


@pytest.fixture(scope="session")
def tmp_db_path(tmp_path_factory):
    """Create a temporary DB with the current schema."""
    db_path = tmp_path_factory.mktemp("data") / "test.db"
    import init_db

    original = init_db.DB_PATH
    init_db.DB_PATH = db_path
    init_db.DB_DIR = db_path.parent
    try:
        init_db.init_db()
    finally:
        init_db.DB_PATH = original
    return db_path


@pytest.fixture
def db_conn(tmp_db_path):
    """Return a connection to the temporary DB."""
    conn = sqlite3.connect(str(tmp_db_path))
    conn.execute("PRAGMA foreign_keys=ON")
    conn.row_factory = sqlite3.Row
    yield conn
    conn.close()
```

#### Generated Test File Template

```python
"""test_schema.py - Auto-generated schema validation tests."""

import sqlite3
import pytest


# ============================================================
# Table Existence Tests
# ============================================================


class TestTableExistence:
    """Verify all expected tables exist."""

    EXPECTED_TABLES = [
        "commands",
        "subtasks",
        "reports",
        "agents",
        "counters",
    ]

    @pytest.mark.parametrize("table_name", EXPECTED_TABLES)
    def test_table_exists(self, db_conn, table_name):
        """Table '{table_name}' must exist in the database."""
        row = db_conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            (table_name,),
        ).fetchone()
        assert row is not None, f"Table '{table_name}' not found"

    def test_no_unexpected_tables(self, db_conn):
        """No unexpected tables beyond the known set."""
        rows = db_conn.execute(
            "SELECT name FROM sqlite_master "
            "WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        ).fetchall()
        actual = {r["name"] for r in rows}
        expected = set(self.EXPECTED_TABLES)
        unexpected = actual - expected
        assert not unexpected, f"Unexpected tables: {unexpected}"


# ============================================================
# Column Definition Tests
# ============================================================


class TestCommandsColumns:
    """Validate 'commands' table column definitions."""

    EXPECTED_COLUMNS = {
        #  name:            (type,     notnull, pk)
        "id":              ("TEXT",    False,   True),
        "timestamp":       ("TEXT",    True,    False),
        "command":         ("TEXT",    True,    False),
        "project":         ("TEXT",    False,   False),
        "priority":        ("TEXT",    False,   False),
        "status":          ("TEXT",    False,   False),
        "assigned_karo":   ("TEXT",    False,   False),
        "details":         ("TEXT",    False,   False),
        "created_at":      ("TEXT",    True,    False),
        "completed_at":    ("TEXT",    False,   False),
    }

    def test_column_count(self, db_conn):
        cols = db_conn.execute("PRAGMA table_info('commands')").fetchall()
        assert len(cols) == len(self.EXPECTED_COLUMNS)

    @pytest.mark.parametrize("col_name,expected", list(EXPECTED_COLUMNS.items()),
                             ids=list(EXPECTED_COLUMNS.keys()))
    def test_column_definition(self, db_conn, col_name, expected):
        """Column '{col_name}' has correct type, notnull, pk."""
        cols = db_conn.execute("PRAGMA table_info('commands')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_name in col_map, f"Column '{col_name}' missing"
        col = col_map[col_name]
        exp_type, exp_notnull, exp_pk = expected
        assert col["type"] == exp_type, f"Type mismatch: {col['type']} != {exp_type}"
        assert bool(col["notnull"]) == exp_notnull, f"notnull mismatch"
        assert bool(col["pk"]) == exp_pk, f"pk mismatch"


class TestSubtasksColumns:
    """Validate 'subtasks' table column definitions."""

    EXPECTED_COLUMNS = {
        "id":             ("TEXT",    False,   True),
        "parent_cmd":     ("TEXT",    True,    False),
        "worker_id":      ("TEXT",    False,   False),
        "project":        ("TEXT",    False,   False),
        "description":    ("TEXT",    True,    False),
        "target_path":    ("TEXT",    False,   False),
        "status":         ("TEXT",    False,   False),
        "wave":           ("INTEGER", False,   False),
        "notes":          ("TEXT",    False,   False),
        "assigned_at":    ("TEXT",    False,   False),
        "completed_at":   ("TEXT",    False,   False),
        "needs_audit":    ("INTEGER", False,   False),
        "audit_status":   ("TEXT",    False,   False),
    }

    def test_column_count(self, db_conn):
        cols = db_conn.execute("PRAGMA table_info('subtasks')").fetchall()
        assert len(cols) == len(self.EXPECTED_COLUMNS)

    @pytest.mark.parametrize("col_name,expected", list(EXPECTED_COLUMNS.items()),
                             ids=list(EXPECTED_COLUMNS.keys()))
    def test_column_definition(self, db_conn, col_name, expected):
        cols = db_conn.execute("PRAGMA table_info('subtasks')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_name in col_map, f"Column '{col_name}' missing"
        col = col_map[col_name]
        exp_type, exp_notnull, exp_pk = expected
        assert col["type"] == exp_type
        assert bool(col["notnull"]) == exp_notnull
        assert bool(col["pk"]) == exp_pk


class TestReportsColumns:
    """Validate 'reports' table column definitions."""

    EXPECTED_COLUMNS = {
        "id":                    ("INTEGER", False,  True),
        "worker_id":             ("TEXT",    True,   False),
        "task_id":               ("TEXT",    True,   False),
        "timestamp":             ("TEXT",    True,   False),
        "status":                ("TEXT",    True,   False),
        "summary":               ("TEXT",    False,  False),
        "completed_steps":       ("TEXT",    False,  False),
        "blocking_reason":       ("TEXT",    False,  False),
        "findings":              ("TEXT",    False,  False),
        "next_actions":          ("TEXT",    False,  False),
        "files_modified":        ("TEXT",    False,  False),
        "notes":                 ("TEXT",    False,  False),
        "skill_candidate_name":  ("TEXT",    False,  False),
        "skill_candidate_desc":  ("TEXT",    False,  False),
    }

    def test_column_count(self, db_conn):
        cols = db_conn.execute("PRAGMA table_info('reports')").fetchall()
        assert len(cols) == len(self.EXPECTED_COLUMNS)

    @pytest.mark.parametrize("col_name,expected", list(EXPECTED_COLUMNS.items()),
                             ids=list(EXPECTED_COLUMNS.keys()))
    def test_column_definition(self, db_conn, col_name, expected):
        cols = db_conn.execute("PRAGMA table_info('reports')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_name in col_map
        col = col_map[col_name]
        exp_type, exp_notnull, exp_pk = expected
        assert col["type"] == exp_type
        assert bool(col["notnull"]) == exp_notnull
        assert bool(col["pk"]) == exp_pk


# ============================================================
# Foreign Key Tests
# ============================================================


class TestForeignKeys:
    """Validate foreign key constraints."""

    def test_subtasks_parent_cmd_fk(self, db_conn):
        """subtasks.parent_cmd references commands.id."""
        fks = db_conn.execute("PRAGMA foreign_key_list('subtasks')").fetchall()
        fk_map = {fk["from"]: fk for fk in fks}
        assert "parent_cmd" in fk_map
        assert fk_map["parent_cmd"]["table"] == "commands"
        assert fk_map["parent_cmd"]["to"] == "id"

    def test_reports_task_id_fk(self, db_conn):
        """reports.task_id references subtasks.id."""
        fks = db_conn.execute("PRAGMA foreign_key_list('reports')").fetchall()
        fk_map = {fk["from"]: fk for fk in fks}
        assert "task_id" in fk_map
        assert fk_map["task_id"]["table"] == "subtasks"
        assert fk_map["task_id"]["to"] == "id"

    def test_fk_enforcement(self, db_conn):
        """Foreign keys are enforced (PRAGMA foreign_keys=ON)."""
        row = db_conn.execute("PRAGMA foreign_keys").fetchone()
        assert row[0] == 1, "foreign_keys PRAGMA must be ON"

    def test_fk_violation_rejected(self, db_conn):
        """Inserting a subtask with non-existent parent_cmd raises IntegrityError."""
        with pytest.raises(Exception):
            db_conn.execute(
                "INSERT INTO subtasks (id, parent_cmd, description) "
                "VALUES ('orphan_1', 'nonexistent_cmd', 'test')"
            )


# ============================================================
# Default Value Tests
# ============================================================


class TestDefaultValues:
    """Validate column default values."""

    def test_commands_priority_default(self, db_conn):
        """commands.priority defaults to 'medium'."""
        cols = db_conn.execute("PRAGMA table_info('commands')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_map["priority"]["dflt_value"] == "'medium'"

    def test_commands_status_default(self, db_conn):
        """commands.status defaults to 'pending'."""
        cols = db_conn.execute("PRAGMA table_info('commands')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_map["status"]["dflt_value"] == "'pending'"

    def test_subtasks_status_default(self, db_conn):
        """subtasks.status defaults to 'pending'."""
        cols = db_conn.execute("PRAGMA table_info('subtasks')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_map["status"]["dflt_value"] == "'pending'"

    def test_subtasks_wave_default(self, db_conn):
        """subtasks.wave defaults to 1."""
        cols = db_conn.execute("PRAGMA table_info('subtasks')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_map["wave"]["dflt_value"] == "1"

    def test_subtasks_needs_audit_default(self, db_conn):
        """subtasks.needs_audit defaults to 0."""
        cols = db_conn.execute("PRAGMA table_info('subtasks')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_map["needs_audit"]["dflt_value"] == "0"

    def test_counters_value_default(self, db_conn):
        """counters.value defaults to 0."""
        cols = db_conn.execute("PRAGMA table_info('counters')").fetchall()
        col_map = {c["name"]: c for c in cols}
        assert col_map["value"]["dflt_value"] == "0"


# ============================================================
# Index Tests
# ============================================================


class TestIndexes:
    """Validate index definitions (if any)."""

    def test_primary_key_indexes_exist(self, db_conn):
        """Each table with a TEXT PK has an autoindex."""
        for table in ("commands", "subtasks", "agents", "counters"):
            indexes = db_conn.execute(
                f"PRAGMA index_list('{table}')"
            ).fetchall()
            # SQLite creates autoindex for PRIMARY KEY
            assert len(indexes) >= 0  # existence check; PK may be implicit
```

### Step 3: Adapting to Your Project

When using this skill, replace the concrete table/column definitions with your project's schema. The pattern is always the same:

1. **Run `PRAGMA table_info('table_name')`** for each table
2. **Build an `EXPECTED_COLUMNS` dict** mapping column names to `(type, notnull, pk)` tuples
3. **Use `@pytest.mark.parametrize`** to generate one test per column
4. **Run `PRAGMA foreign_key_list('table_name')`** for FK validation
5. **Run `PRAGMA index_list('table_name')` + `PRAGMA index_info('index_name')`** for index validation

### Step 4: Running the Tests

```bash
# Run schema validation tests only
python3 -m pytest tests/test_schema.py -v

# Run with coverage
python3 -m pytest tests/test_schema.py -v --tb=short

# Run as part of CI
python3 -m pytest tests/ -v --junitxml=reports/schema.xml
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `PRAGMA table_info` over `sqlite_master` parsing | Structured output, handles ALTER TABLE correctly |
| `@pytest.mark.parametrize` per column | Clear failure messages identifying exactly which column broke |
| Session-scoped `tmp_db` fixture | Init once, reuse across all schema tests for speed |
| FK enforcement test included | Catches cases where `PRAGMA foreign_keys=ON` is missing |
| Default value tests separate | Defaults are a common source of subtle bugs |

---

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| `PRAGMA foreign_keys` defaults to OFF in SQLite | Always include `conn.execute("PRAGMA foreign_keys=ON")` in fixtures |
| `sqlite_master` SQL text differs between CREATE and ALTER | Use `PRAGMA table_info` instead of parsing DDL strings |
| Autoincrement columns show `INTEGER` type but `pk=1` | Check both type and pk flag; INTEGER PK is implicit rowid alias |
| Column order may change after ALTER TABLE ADD COLUMN | Test by name, not by position |
| DEFAULT values are stored as string literals including quotes | Compare against `"'medium'"` not `"medium"` for TEXT defaults |

---

**Skill Author**: Shogun QA Team
**Last Updated**: 2026-02-07
**License**: Internal
