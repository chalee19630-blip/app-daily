# 🧪 ProjectPilot Security Test Plan

**Version**: 2.0 (Post-Audit Fix)
**Date**: 2026-10-12
**Status**: ✅ SAFE FOR TESTING

---

## 📋 Prerequisites

### 1. Test Environment Setup

```bash
# ใช้ dedicated test project หรือ local Supabase
# ⚠️ ห้ามใช้ production project

# Option A: Local Supabase (แนะนำ)
supabase start

# Option B: Test Project on Supabase Cloud
# สร้าง project ใหม่ชื่อ "projectpilot-test-xxx"
```

### 2. Create Test Users

**ผ่าน Supabase Dashboard** (ห้ามใช้ SQL):

1. ไปที่ **Authentication > Users**
2. คลิก **Add User**
3. สร้าง users:

| Email | Password | Role |
|-------|----------|------|
| `test-owner-1@example.com` | `TestPass123!` | Primary Owner |
| `test-owner-2@example.com` | `TestPass123!` | Secondary Owner |
| `test-admin@example.com` | `TestPass123!` | Admin |
| `test-member@example.com` | `TestPass123!` | Member |

4. หลังจากสร้าง ให้ copy **User UUID** จากแต่ละ user

### 3. Get Service Role Key

```bash
# Dashboard > Settings > API > service_role key
# หรือ local:
supabase status | grep service_role
```

---

## 🗂️ Test Structure

### Category A: Catalog Checks (ไม่ต้องใช้ authenticated user)

ใช้ SQL Editor กับ `postgres` role หรือ service role key

#### Test A1: Verify RLS Enabled

```sql
-- รันใน SQL Editor
SELECT 
  tablename,
  rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

**Expected Result**:
```
tablename         | rls_enabled
------------------|-------------
profiles          | t
workspaces        | t
workspace_members | t
projects          | t
tasks             | t
```

**ถ้าผ่าน**: ✅ RLS enabled on all tables

---

#### Test A2: Verify All Policies Exist

```sql
SELECT 
  tablename,
  COUNT(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;
```

**Expected Result**:
```
tablename         | policy_count
------------------|-------------
profiles          | 3
workspaces        | 4
workspace_members | 4
projects          | 4
tasks             | 4
```

**ถ้าผ่าน**: ✅ All policies created (19 total)

---

#### Test A3: Verify All Triggers Exist

```sql
SELECT 
  event_object_table AS table_name,
  trigger_name,
  action_timing AS timing,
  event_manipulation AS event
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
```

**Expected Result**: 12 triggers
- `handle_profiles_updated_at`
- `handle_workspaces_updated_at`
- `handle_projects_updated_at`
- `handle_tasks_updated_at`
- `on_auth_user_created`
- `on_workspace_created`
- `prevent_project_workspace_change`
- `prevent_task_cross_workspace_move`
- `prevent_direct_owner_change`
- `prevent_last_owner_deletion`
- `prevent_last_owner_demotion`

**ถ้าผ่าน**: ✅ All triggers created

---

#### Test A4: Verify All Functions Have Safe search_path

```sql
SELECT 
  p.proname AS function_name,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND pg_get_functiondef(p.oid) LIKE '%SECURITY DEFINER%'
ORDER BY p.proname;
```

**Check**: ทุก function ต้องมี `SET search_path = ''`

**ถ้าผ่าน**: ✅ All SECURITY DEFINER functions are safe

---

### Category B: Setup Test Data (ต้องใช้ authenticated user)

**วิธีการ**: ใช้ `psql` กับ user impersonation

```bash
# สร้าง test script
cat > test_setup.sql << 'EOF'
-- ============================================
-- Impersonate Test Owner 1
-- ============================================
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

-- Create Workspace 1
INSERT INTO workspaces (name, owner_id)
VALUES ('Test-ABC123 Workspace 1', auth.uid())
RETURNING id;

-- เก็บ workspace_id ไว้ใช้ต่อ
-- Replace <WORKSPACE_1_UUID> ในทุก statement ด้านล่าง

-- Add other users as members
INSERT INTO workspace_members (workspace_id, user_id, role) VALUES
('<WORKSPACE_1_UUID>', '<USER_B_UUID>', 'admin'),
('<WORKSPACE_1_UUID>', '<USER_C_UUID>', 'admin'),
('<WORKSPACE_1_UUID>', '<USER_D_UUID>', 'member');

-- Add User B as co-owner
SELECT add_workspace_owner('<WORKSPACE_1_UUID>', '<USER_B_UUID>');

-- Create test project
INSERT INTO projects (workspace_id, name, created_by)
VALUES ('<WORKSPACE_1_UUID>', 'Test-ABC123 Project 1', auth.uid())
RETURNING id;

-- เก็บ project_id

-- Create test task
INSERT INTO tasks (project_id, title, created_by)
VALUES ('<PROJECT_1_UUID>', 'Test-ABC123 Task 1', auth.uid())
RETURNING id;

-- ============================================
-- Impersonate Test Owner 2
-- ============================================
-- (ใช้ separate transaction)
EOF

# รันด้วย service role key
psql "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres" \
  -f test_setup.sql
```

**หรือใช้ Supabase CLI**:

```bash
# ใช้ JS script
cat > setup_test_data.js << 'EOF'
const { createClient } = require('@supabase/supabase-js')

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
)

async function setup() {
  // Create workspace for User A
  const { data: ws1 } = await supabase.from('workspaces')
    .insert({ name: 'Test-ABC123 WS1', owner_id: '<USER_A_UUID>' })
    .select()
    .single()
  
  // Add members
  await supabase.from('workspace_members').insert([
    { workspace_id: ws1.id, user_id: '<USER_B_UUID>', role: 'admin' },
    { workspace_id: ws1.id, user_id: '<USER_C_UUID>', role: 'admin' },
    { workspace_id: ws1.id, user_id: '<USER_D_UUID>', role: 'member' }
  ])
  
  // Add co-owner
  await supabase.rpc('add_workspace_owner', {
    workspace_uuid: ws1.id,
    new_owner_uuid: '<USER_B_UUID>'
  })
  
  console.log('Setup complete. Workspace ID:', ws1.id)
}

setup()
EOF

SUPABASE_URL=https://xxx.supabase.co \
SUPABASE_SERVICE_KEY=xxx \
node setup_test_data.js
```

---

### Category C: Last Owner Protection Tests

#### Test C1: Remove Last Owner via DELETE (Single Owner)

```sql
-- Impersonate User A
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

-- Verify workspace has single owner
SELECT COUNT(*) FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_SINGLE_OWNER_UUID>' 
AND role = 'owner';
-- Expected: 1

-- Try to delete self (should fail)
BEGIN;
DELETE FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_SINGLE_OWNER_UUID>' 
AND user_id = auth.uid();
-- Expected: ERROR from trigger
ROLLBACK;
```

**Expected Result**:
```
ERROR: Cannot remove the last owner of the workspace. Transfer ownership first.
```

**ถ้าผ่าน**: ✅ Last owner deletion blocked by trigger

---

#### Test C2: Demote Last Owner via UPDATE

```sql
-- Impersonate User A (single owner)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

BEGIN;
UPDATE workspace_members 
SET role = 'admin'
WHERE workspace_id = '<WORKSPACE_SINGLE_OWNER_UUID>'
AND user_id = auth.uid();
-- Expected: ERROR from trigger
ROLLBACK;
```

**Expected Result**:
```
ERROR: Cannot demote the last owner of the workspace. Transfer ownership first.
```

**ถ้าผ่าน**: ✅ Last owner demotion blocked by trigger

---

#### Test C3: Remove Owner When Multiple Owners Exist

```sql
-- Impersonate User A (workspace has 2 owners: A and B)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

-- Verify 2 owners exist
SELECT COUNT(*) FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_MULTI_OWNER_UUID>' 
AND role = 'owner';
-- Expected: 2

-- Remove User B (should succeed)
BEGIN;
DELETE FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_MULTI_OWNER_UUID>' 
AND user_id = '<USER_B_UUID>';
-- Expected: DELETE 1
COMMIT;

-- Verify 1 owner remains
SELECT COUNT(*) FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_MULTI_OWNER_UUID>' 
AND role = 'owner';
-- Expected: 1
```

**ถ้าผ่าน**: ✅ Owner removal succeeds when not last owner

---

### Category D: Ownership Transfer Tests

#### Test D1: Successful Transfer

```sql
-- Impersonate User A (current owner)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

BEGIN;
SELECT transfer_workspace_ownership(
  '<WORKSPACE_UUID>',
  '<USER_C_UUID>'  -- Admin user
);

-- Verify: User A is now admin, User C is owner
SELECT user_id, role FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_UUID>'
ORDER BY role;
COMMIT;
```

**Expected Result**:
```
user_id          | role
-----------------|-------
<USER_A_UUID>    | admin
<USER_C_UUID>    | owner
```

**ถ้าผ่าน**: ✅ Ownership transfer atomic

---

#### Test D2: Non-Owner Cannot Transfer

```sql
-- Impersonate User D (member role)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_D_UUID>"}';

BEGIN;
SELECT transfer_workspace_ownership(
  '<WORKSPACE_UUID>',
  '<USER_D_UUID>'
);
-- Expected: ERROR
ROLLBACK;
```

**Expected Result**:
```
ERROR: Only workspace owners can transfer ownership
```

**ถ้าผ่าน**: ✅ Transfer authorization enforced

---

#### Test D3: Transfer to Non-Member

```sql
-- Impersonate User A (owner)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

BEGIN;
SELECT transfer_workspace_ownership(
  '<WORKSPACE_UUID>',
  '<RANDOM_NON_MEMBER_UUID>'
);
-- Expected: ERROR
ROLLBACK;
```

**Expected Result**:
```
ERROR: New owner must be a member of the workspace
```

**ถ้าผ่าน**: ✅ Transfer validates membership

---

#### Test D4: Transfer to Self

```sql
-- Impersonate User A (owner)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

BEGIN;
SELECT transfer_workspace_ownership(
  '<WORKSPACE_UUID>',
  '<USER_A_UUID>'  -- Self
);
-- Expected: ERROR
ROLLBACK;
```

**Expected Result**:
```
ERROR: Cannot transfer ownership to yourself
```

**ถ้าผ่าน**: ✅ Self-transfer blocked

---

### Category E: Add Co-Owner Tests

#### Test E1: Owner Adds Co-Owner

```sql
-- Impersonate User A (owner)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

-- User C is currently admin
SELECT role FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_UUID>' 
AND user_id = '<USER_C_UUID>';
-- Expected: admin

BEGIN;
SELECT add_workspace_owner(
  '<WORKSPACE_UUID>',
  '<USER_C_UUID>'
);

-- Verify User C is now owner
SELECT role FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_UUID>' 
AND user_id = '<USER_C_UUID>';
-- Expected: owner
COMMIT;
```

**Expected Result**: User C role changes from `admin` → `owner`

**ถ้าผ่าน**: ✅ Add co-owner function works

---

#### Test E2: Non-Owner Cannot Add Owner

```sql
-- Impersonate User D (member)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_D_UUID>"}';

BEGIN;
SELECT add_workspace_owner(
  '<WORKSPACE_UUID>',
  '<USER_D_UUID>'
);
-- Expected: ERROR
ROLLBACK;
```

**Expected Result**:
```
ERROR: Only workspace owners can add owners
```

**ถ้าผ่าน**: ✅ Add owner authorization enforced

---

### Category F: Concurrent Modification Tests

**⚠️ ต้องใช้ external tools (psql หรือ script)**

#### Test F1: Concurrent Last Owner Removal

**Setup**: Workspace with 2 owners (User A and User B)

**Terminal 1**:
```bash
psql "postgresql://...[service_role]..." << 'EOF'
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

BEGIN;
-- This should get lock first
DELETE FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_UUID>' 
AND user_id = '<USER_B_UUID>';

-- Hold transaction open for 10 seconds
SELECT pg_sleep(10);
COMMIT;
EOF
```

**Terminal 2** (รันทันทีหลังจาก Terminal 1):
```bash
psql "postgresql://...[service_role]..." << 'EOF'
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_B_UUID>"}';

BEGIN;
-- This should block waiting for lock
DELETE FROM workspace_members 
WHERE workspace_id = '<WORKSPACE_UUID>' 
AND user_id = '<USER_A_UUID>';

-- Expected: After Terminal 1 commits, this should fail
-- ERROR: Cannot remove the last owner...
ROLLBACK;
EOF
```

**Expected Behavior**:
1. Terminal 1: Succeeds, removes User B, workspace has 1 owner
2. Terminal 2: Blocks, then resumes, sees 1 owner, fails with error

**ถ้าผ่าน**: ✅ FOR UPDATE lock serializes concurrent deletions

---

### Category G: RBAC Tests

#### Test G1: Member Cannot Promote Self

```sql
-- Impersonate User D (member)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_D_UUID>"}';

BEGIN;
UPDATE workspace_members 
SET role = 'admin'
WHERE workspace_id = '<WORKSPACE_UUID>'
AND user_id = auth.uid();
-- Expected: UPDATE 0 (policy denies, no error)
ROLLBACK;
```

**Expected Result**: `UPDATE 0` (policy USING clause returns false)

**ถ้าผ่าน**: ✅ Self-promotion prevented by RLS

---

#### Test G2: Admin Cannot Promote Member to Owner

```sql
-- Impersonate User C (admin)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_C_UUID>"}';

BEGIN;
UPDATE workspace_members 
SET role = 'owner'
WHERE workspace_id = '<WORKSPACE_UUID>'
AND user_id = '<USER_D_UUID>';
-- Expected: UPDATE 0 (policy denies role='owner')
ROLLBACK;
```

**Expected Result**: `UPDATE 0`

**ถ้าผ่าน**: ✅ Owner promotion restricted to transfer function

---

#### Test G3: Owner Cannot Change Own Role

```sql
-- Impersonate User A (owner)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

BEGIN;
UPDATE workspace_members 
SET role = 'admin'
WHERE workspace_id = '<WORKSPACE_UUID>'
AND user_id = auth.uid();
-- Expected: UPDATE 0 (policy denies user_id = auth.uid())
ROLLBACK;
```

**Expected Result**: `UPDATE 0`

**ถ้าผ่าน**: ✅ Self-role-change prevented

---

### Category H: Cross-Workspace Isolation Tests

#### Test H1: Cannot Read Other Workspace Projects

```sql
-- Impersonate User A (member of Workspace 1 only)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

-- Try to read Workspace 2 projects
SELECT * FROM projects 
WHERE workspace_id = '<WORKSPACE_2_UUID>';
-- Expected: 0 rows
```

**Expected Result**: `(0 rows)`

**ถ้าผ่าน**: ✅ Cross-workspace isolation works

---

#### Test H2: Cannot Move Project Between Workspaces

```sql
-- Impersonate User A (owner of Workspace 1)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

BEGIN;
UPDATE projects 
SET workspace_id = '<WORKSPACE_2_UUID>'
WHERE id = '<PROJECT_1_UUID>';
-- Expected: ERROR from trigger
ROLLBACK;
```

**Expected Result**:
```
ERROR: Cannot change project workspace_id. Delete and recreate the project instead.
```

**ถ้าผ่าน**: ✅ Project workspace immutability enforced

---

#### Test H3: Cannot Assign Task to Member of Different Workspace

```sql
-- Impersonate User A (Workspace 1)
-- User E is member of Workspace 2 only

SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

BEGIN;
INSERT INTO tasks (project_id, title, assigned_to, created_by)
VALUES ('<PROJECT_1_UUID>', 'Test Task', '<USER_E_UUID>', auth.uid());
-- Expected: ERROR (policy denies non-member assignee)
ROLLBACK;
```

**Expected Result**: Policy denies insert

**ถ้าผ่าน**: ✅ Assignee validation works

---

## 🧹 Safe Cleanup

### Method 1: Tag-Based Cleanup (แนะนำ)

```sql
-- ใช้ tagging ตั้งแต่ setup
-- Example: 'Test-ABC123-Workspace-1'

-- Cleanup
BEGIN;
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub": "<USER_A_UUID>"}';

-- Delete only tagged objects
DELETE FROM tasks 
WHERE title LIKE 'Test-ABC123-%';

DELETE FROM projects 
WHERE name LIKE 'Test-ABC123-%';

DELETE FROM workspace_members 
WHERE workspace_id IN (
  SELECT id FROM workspaces WHERE name LIKE 'Test-ABC123-%'
);

DELETE FROM workspaces 
WHERE name LIKE 'Test-ABC123-%'
AND owner_id = auth.uid();

COMMIT;
```

### Method 2: Service Role Cleanup (สำหรับ admin)

```sql
-- ⚠️ ใช้ service role key เท่านั้น
BEGIN;

-- Delete all test data (safe with tag)
DELETE FROM tasks WHERE title LIKE 'Test-ABC123-%';
DELETE FROM projects WHERE name LIKE 'Test-ABC123-%';
DELETE FROM workspace_members WHERE workspace_id IN (
  SELECT id FROM workspaces WHERE name LIKE 'Test-ABC123-%'
);
DELETE FROM workspaces WHERE name LIKE 'Test-ABC123-%';

-- Delete test users (ถ้าต้องการ)
DELETE FROM auth.users WHERE email LIKE 'test-%@example.com';

COMMIT;
```

---

## 📊 Test Execution Checklist

### Pre-Test (Catalog Checks)
- [ ] A1: RLS enabled on all tables
- [ ] A2: All policies exist (19 total)
- [ ] A3: All triggers exist (12 total)
- [ ] A4: All SECURITY DEFINER functions safe

### Setup Test Data
- [ ] Create test users via Dashboard
- [ ] Run setup script with tagging
- [ ] Verify test data exists

### Last Owner Protection
- [ ] C1: Remove last owner fails
- [ ] C2: Demote last owner fails
- [ ] C3: Remove owner when multiple exists succeeds

### Ownership Transfer
- [ ] D1: Successful transfer
- [ ] D2: Non-owner cannot transfer
- [ ] D3: Transfer to non-member fails
- [ ] D4: Transfer to self fails

### Add Co-Owner
- [ ] E1: Owner adds co-owner
- [ ] E2: Non-owner cannot add owner

### Concurrent Tests (Optional)
- [ ] F1: Concurrent last owner removal (requires psql)

### RBAC
- [ ] G1: Member cannot promote self
- [ ] G2: Admin cannot promote to owner
- [ ] G3: Owner cannot change own role

### Cross-Workspace
- [ ] H1: Cannot read other workspace
- [ ] H2: Cannot move project
- [ ] H3: Cannot assign to non-member

### Cleanup
- [ ] Delete tagged test data
- [ ] Verify cleanup complete

---

## 🚨 Important Notes

1. **ห้ามใช้ production project** - ใช้ dedicated test project เท่านั้น
2. **ใช้ tagging** - ทุก object ต้องมี unique tag เช่น `Test-ABC123-...`
3. **Cleanup ทุกครั้ง** - หลังจาก test เสร็จให้ cleanup ทันที
4. **Verify ก่อน cleanup** - ตรวจสอบว่าจะลบเฉพาะ test data
5. **Concurrent tests** - ต้องใช้ external tools (psql/script)
6. **auth.uid() context** - ต้องใช้ user impersonation ทุกครั้ง

---

## 📝 Test Report Template

```markdown
## ProjectPilot Security Test Report

**Date**: _______________
**Tester**: _______________
**Environment**: ☐ Local  ☐ Cloud Test Project
**Tag Used**: Test-_____________

### Catalog Checks
- [A1] RLS Enabled: ☐ PASS  ☐ FAIL
- [A2] Policies Exist: ☐ PASS  ☐ FAIL
- [A3] Triggers Exist: ☐ PASS  ☐ FAIL
- [A4] Safe search_path: ☐ PASS  ☐ FAIL

### Security Tests
| Test | Description | Result |
|------|-------------|--------|
| C1 | Remove last owner | ☐ PASS  ☐ FAIL  ☐ SKIP |
| C2 | Demote last owner | ☐ PASS  ☐ FAIL  ☐ SKIP |
| C3 | Remove owner (multi) | ☐ PASS  ☐ FAIL  ☐ SKIP |
| D1 | Transfer success | ☐ PASS  ☐ FAIL  ☐ SKIP |
| D2 | Non-owner transfer | ☐ PASS  ☐ FAIL  ☐ SKIP |
| D3 | Transfer non-member | ☐ PASS  ☐ FAIL  ☐ SKIP |
| D4 | Transfer to self | ☐ PASS  ☐ FAIL  ☐ SKIP |
| E1 | Add co-owner | ☐ PASS  ☐ FAIL  ☐ SKIP |
| E2 | Non-owner add | ☐ PASS  ☐ FAIL  ☐ SKIP |
| F1 | Concurrent removal | ☐ PASS  ☐ FAIL  ☐ SKIP |
| G1 | Self-promotion | ☐ PASS  ☐ FAIL  ☐ SKIP |
| G2 | Admin->owner | ☐ PASS  ☐ FAIL  ☐ SKIP |
| G3 | Self-role-change | ☐ PASS  ☐ FAIL  ☐ SKIP |
| H1 | Read cross-workspace | ☐ PASS  ☐ FAIL  ☐ SKIP |
| H2 | Move project | ☐ PASS  ☐ FAIL  ☐ SKIP |
| H3 | Assign non-member | ☐ PASS  ☐ FAIL  ☐ SKIP |

### Issues Found
- [List any failures or unexpected behavior]

### Cleanup Completed
- [ ] All test data deleted
- [ ] Test users deleted (optional)

### Recommendations
- [Pass/Fail for migration application]
```

---

**Ready for controlled testing** ✅
