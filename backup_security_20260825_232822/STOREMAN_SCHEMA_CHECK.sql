
-- ============================================================
-- STOREMAN DATABASE SCHEMA + CONSTRAINT + RLS CHECK
-- READ-ONLY DIAGNOSTIC
-- ============================================================

-- ============================================================
-- 1. TABLE COLUMNS
-- ============================================================

SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name IN (
    'companies',
    'profiles',
    'user_permissions',
    'activity_logs',
    'materials',
    'transactions',
    'sales_orders',
    'store_backups',
    'warehouses',
    'suppliers',
    'customers',
    'invoices'
)
ORDER BY
    table_name,
    ordinal_position;


-- ============================================================
-- 2. PRIMARY / FOREIGN / UNIQUE / CHECK CONSTRAINTS
-- ============================================================

SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
    AND tc.table_name = kcu.table_name
WHERE tc.table_schema = 'public'
AND tc.table_name IN (
    'companies',
    'profiles',
    'user_permissions',
    'activity_logs',
    'materials',
    'transactions',
    'sales_orders',
    'store_backups',
    'warehouses',
    'suppliers',
    'customers',
    'invoices'
)
ORDER BY
    tc.table_name,
    tc.constraint_name,
    kcu.ordinal_position;


-- ============================================================
-- 3. CHECK CONSTRAINT DEFINITIONS
-- ============================================================

SELECT
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
AND conrelid::regclass::text IN (
    'public.companies',
    'public.profiles',
    'public.user_permissions',
    'public.activity_logs',
    'public.materials',
    'public.transactions',
    'public.sales_orders',
    'public.store_backups',
    'public.warehouses',
    'public.suppliers',
    'public.customers',
    'public.invoices'
)
AND contype = 'c'
ORDER BY
    conrelid::regclass::text,
    conname;


-- ============================================================
-- 4. RLS STATUS
-- ============================================================

SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled,
    c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n
    ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
AND c.relname IN (
    'companies',
    'profiles',
    'user_permissions',
    'activity_logs',
    'materials',
    'transactions',
    'sales_orders',
    'store_backups',
    'warehouses',
    'suppliers',
    'customers',
    'invoices'
)
ORDER BY
    c.relname;


-- ============================================================
-- 5. RLS POLICIES
-- ============================================================

SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN (
    'companies',
    'profiles',
    'user_permissions',
    'activity_logs',
    'materials',
    'transactions',
    'sales_orders',
    'store_backups',
    'warehouses',
    'suppliers',
    'customers',
    'invoices'
)
ORDER BY
    tablename,
    policyname;


-- ============================================================
-- 6. PROFILES ROLE CHECK
-- ============================================================

SELECT
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.profiles'::regclass
AND contype = 'c';


-- ============================================================
-- 7. PROFILES TABLE STRUCTURE
-- ============================================================

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'profiles'
ORDER BY ordinal_position;


-- ============================================================
-- 8. CURRENT ADMIN PROFILE
-- ============================================================

SELECT
    p.id,
    u.email,
    p.full_name,
    p.company_id,
    p.role,
    p.status,
    p.warehouse_id,
    p.permissions,
    p.last_login_at,
    p.last_seen_at
FROM public.profiles p
LEFT JOIN auth.users u
    ON u.id = p.id
ORDER BY
    p.role,
    u.email;


-- ============================================================
-- 9. COMPANIES
-- ============================================================

SELECT
    id,
    name,
    slug,
    status
FROM public.companies
ORDER BY name;


-- ============================================================
-- 10. PROFILE / COMPANY CONNECTION
-- ============================================================

SELECT
    p.id AS user_id,
    u.email,
    p.role,
    p.status,
    p.company_id,
    c.name AS company_name,
    c.slug AS company_slug
FROM public.profiles p
LEFT JOIN auth.users u
    ON u.id = p.id
LEFT JOIN public.companies c
    ON c.id = p.company_id
ORDER BY
    c.name,
    u.email;


-- ============================================================
-- 11. FUNCTIONS USED BY RLS
-- ============================================================

SELECT
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid)
        AS arguments,
    pg_get_function_result(p.oid)
        AS return_type
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname IN (
    'current_company_id',
    'is_admin',
    'is_owner',
    'has_permission'
)
ORDER BY p.proname;


-- ============================================================
-- 12. FOREIGN KEYS
-- ============================================================

SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table,
    ccu.column_name AS foreign_column,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_schema = 'public'
AND tc.table_name IN (
    'companies',
    'profiles',
    'user_permissions',
    'activity_logs',
    'materials',
    'transactions',
    'sales_orders',
    'store_backups',
    'warehouses',
    'suppliers',
    'customers',
    'invoices'
)
ORDER BY
    tc.table_name,
    kcu.column_name;


-- ============================================================
-- END
-- ============================================================

SELECT
    'STOREMAN SCHEMA CHECK COMPLETE' AS status;

