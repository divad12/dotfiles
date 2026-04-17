# Sample Feature Implementation Plan

> Test fixture for /preflight - do not execute.

**Goal:** Add a CSV export endpoint to the reporting service.

**Architecture:** HTTP endpoint → query builder → CSV serializer → response stream.

**Tech Stack:** Python, FastAPI, pandas.

---

## Phase 1: Schema and Models

### Task 1: Add `exports` table migration

**Files:**
- Create: `db/migrations/005_exports.sql`
- Test: `tests/db/test_005_exports.py`

- [ ] Step 1: Write failing test for table existence
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Write migration SQL
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit

### Task 2: Add Pydantic `ExportRequest` model

**Files:**
- Create: `api/models/export.py`
- Test: `tests/api/test_export_model.py`

- [ ] Step 1: Define model class
- [ ] Step 2: Commit

### Task 3: Add `ExportRow` serializer helper

**Files:**
- Create: `api/serializers/export_row.py`

- [ ] Step 1: Implement serializer
- [ ] Step 2: Commit

## Phase 2: Query and Endpoint

### Task 4: Build query construction module

**Files:**
- Create: `api/services/export_query.py`
- Modify: `api/services/__init__.py`
- Test: `tests/api/services/test_export_query.py`

- [ ] Step 1: Write failing test for query builder
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Implement query builder
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit

### Task 5: Wire the endpoint with streaming CSV response

**Files:**
- Create: `api/routes/exports.py`
- Modify: `api/main.py` (register route)
- Test: `tests/api/routes/test_exports.py`

- [ ] Step 1: Write integration test hitting the endpoint
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Implement endpoint with StreamingResponse
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit
