-- ============================================================
-- STOREMAN SECURITY / RLS MASTER
-- ============================================================
--
-- PURPOSE:
--   1. Pending user approval
--   2. Company isolation
--   3. Warehouse isolation
--   4. Permission-aware access
--   5. Admin/Owner management
--   6. Activity logs
--
-- IMPORTANT:
--   Run this file in Supabase SQL Editor.
--
-- ============================================================


-- ============================================================
-- 1. PROFILES: PENDING APPROVAL
-- ============================================================

DO $$
BEGIN

    IF to_regclass('public.profiles') IS NULL THEN
        RAISE NOTICE 'profiles table not found - skipped';
        RETURN;
    END IF;

    -- Add pending status support if the existing status
    -- column is text/varchar.
    --
    -- We do NOT blindly replace an existing constraint.
    -- Existing project constraints are preserved.

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema='public'
        AND table_name='profiles'
        AND column_name='status'
        AND data_type IN ('text','character varying')
    ) THEN

        -- Remove common old status check constraints only
        -- when they explicitly restrict the status values.
        FOR r IN
            SELECT conname
            FROM pg_constraint
            WHERE conrelid='public.profiles'::regclass
            AND contype='c'
            AND pg_get_constraintdef(oid) ILIKE '%status%'
        LOOP
            EXECUTE format(
                'ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS %I',
                r.conname
            );
        END LOOP;

        ALTER TABLE public.profiles
        ADD CONSTRAINT profiles_status_allowed
        CHECK (
            status IS NULL
            OR status IN (
                'pending',
                'active',
                'blocked',
                'disabled'
            )
        );

    END IF;

END $$;


-- ============================================================
-- 2. HELPER: CURRENT PROFILE
-- ============================================================

CREATE OR REPLACE FUNCTION public.storeman_current_profile()
RETURNS public.profiles
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p.*
    FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
    LIMIT 1;
$$;


-- ============================================================
-- 3. HELPER: CURRENT COMPANY
-- ============================================================

CREATE OR REPLACE FUNCTION public.storeman_current_company_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p.company_id
    FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
    AND COALESCE(p.status,'active') = 'active'
    LIMIT 1;
$$;


-- ============================================================
-- 4. HELPER: CURRENT WAREHOUSE
-- ============================================================

CREATE OR REPLACE FUNCTION public.storeman_current_warehouse_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p.warehouse_id
    FROM public.profiles p
    WHERE p.id = (SELECT auth.uid())
    AND COALESCE(p.status,'active') = 'active'
    LIMIT 1;
$$;


-- ============================================================
-- 5. HELPER: ADMIN / OWNER
-- ============================================================

CREATE OR REPLACE FUNCTION public.storeman_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
        AND p.status = 'active'
        AND p.role IN ('admin','owner')
    );
$$;


-- ============================================================
-- 6. ACTIVE USER
-- ============================================================

CREATE OR REPLACE FUNCTION public.storeman_is_active()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
        AND p.status = 'active'
    );
$$;


-- ============================================================
-- 7. ENABLE RLS
-- ============================================================

DO $$
DECLARE
    t text;
BEGIN

    FOREACH t IN ARRAY ARRAY[
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
    ]
    LOOP

        IF to_regclass('public.' || t) IS NOT NULL THEN

            EXECUTE format(
                'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
                t
            );

            EXECUTE format(
                'ALTER TABLE public.%I FORCE ROW LEVEL SECURITY',
                t
            );

        END IF;

    END LOOP;

END $$;


-- ============================================================
-- 8. REMOVE OLD STOREMAN SECURITY POLICIES
-- ============================================================

DO $$
DECLARE
    r record;
BEGIN

    FOR r IN
        SELECT
            schemaname,
            tablename,
            policyname
        FROM pg_policies
        WHERE schemaname='public'
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
        AND (
            policyname ILIKE 'storeman_%'
            OR policyname ILIKE 'sm_%'
        )
    LOOP

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            r.policyname,
            r.tablename
        );

    END LOOP;

END $$;


-- ============================================================
-- 9. PROFILES
-- ============================================================

DO $$
BEGIN

    IF to_regclass('public.profiles') IS NULL THEN
        RETURN;
    END IF;

    -- User can see only own profile.
    EXECUTE $p$
        CREATE POLICY storeman_profiles_self_select
        ON public.profiles
        FOR SELECT
        TO authenticated
        USING (
            id = (SELECT auth.uid())
            OR (SELECT public.storeman_is_admin())
        );
    $p$;

    -- User can update limited profile information.
    -- Admin/owner can manage profiles.
    EXECUTE $p$
        CREATE POLICY storeman_profiles_update
        ON public.profiles
        FOR UPDATE
        TO authenticated
        USING (
            id = (SELECT auth.uid())
            OR (SELECT public.storeman_is_admin())
        )
        WITH CHECK (
            id = (SELECT auth.uid())
            OR (SELECT public.storeman_is_admin())
        );
    $p$;

END $$;


-- ============================================================
-- 10. GENERIC COMPANY ISOLATION
-- ============================================================

DO $$
DECLARE
    t text;
    has_company boolean;
BEGIN

    FOREACH t IN ARRAY ARRAY[
        'materials',
        'transactions',
        'sales_orders',
        'store_backups',
        'warehouses',
        'suppliers',
        'customers',
        'invoices',
        'activity_logs'
    ]
    LOOP

        IF to_regclass('public.' || t) IS NULL THEN
            CONTINUE;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema='public'
            AND table_name=t
            AND column_name='company_id'
        )
        INTO has_company;

        IF has_company THEN

            EXECUTE format(
                'DROP POLICY IF EXISTS storeman_company_select ON public.%I',
                t
            );

            EXECUTE format(
                'DROP POLICY IF EXISTS storeman_company_insert ON public.%I',
                t
            );

            EXECUTE format(
                'DROP POLICY IF EXISTS storeman_company_update ON public.%I',
                t
            );

            EXECUTE format(
                'DROP POLICY IF EXISTS storeman_company_delete ON public.%I',
                t
            );

            EXECUTE format(
                $p$
                CREATE POLICY storeman_company_select
                ON public.%I
                FOR SELECT
                TO authenticated
                USING (
                    (SELECT public.storeman_is_active())
                    AND (
                        company_id =
                        (SELECT public.storeman_current_company_id())
                        OR
                        (SELECT public.storeman_is_admin())
                    )
                )
                $p$,
                t
            );

            EXECUTE format(
                $p$
                CREATE POLICY storeman_company_insert
                ON public.%I
                FOR INSERT
                TO authenticated
                WITH CHECK (
                    (SELECT public.storeman_is_active())
                    AND (
                        company_id =
                        (SELECT public.storeman_current_company_id())
                        OR
                        (SELECT public.storeman_is_admin())
                    )
                )
                $p$,
                t
            );

            EXECUTE format(
                $p$
                CREATE POLICY storeman_company_update
                ON public.%I
                FOR UPDATE
                TO authenticated
                USING (
                    company_id =
                    (SELECT public.storeman_current_company_id())
                    OR
                    (SELECT public.storeman_is_admin())
                )
                WITH CHECK (
                    company_id =
                    (SELECT public.storeman_current_company_id())
                    OR
                    (SELECT public.storeman_is_admin())
                )
                $p$,
                t
            );

            EXECUTE format(
                $p$
                CREATE POLICY storeman_company_delete
                ON public.%I
                FOR DELETE
                TO authenticated
                USING (
                    company_id =
                    (SELECT public.storeman_current_company_id())
                    OR
                    (SELECT public.storeman_is_admin())
                )
                $p$,
                t
            );

        END IF;

    END LOOP;

END $$;


-- ============================================================
-- 11. WAREHOUSE ISOLATION
-- ============================================================

DO $$
DECLARE
    t text;
    has_warehouse boolean;
BEGIN

    FOREACH t IN ARRAY ARRAY[
        'materials',
        'transactions',
        'sales_orders',
        'store_backups',
        'invoices'
    ]
    LOOP

        IF to_regclass('public.' || t) IS NULL THEN
            CONTINUE;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema='public'
            AND table_name=t
            AND column_name='warehouse_id'
        )
        INTO has_warehouse;

        IF has_warehouse THEN

            EXECUTE format(
                'DROP POLICY IF EXISTS storeman_warehouse_restrict ON public.%I',
                t
            );

            /*
             * RESTRICTIVE policy:
             *
             * Admin/Owner:
             *     full company access.
             *
             * Normal user:
             *     only assigned warehouse.
             *
             * If warehouse_id is NULL, the row is allowed only
             * to company admin/owner.
             */

            EXECUTE format(
                $p$
                CREATE POLICY storeman_warehouse_restrict
                ON public.%I
                AS RESTRICTIVE
                FOR ALL
                TO authenticated
                USING (
                    (SELECT public.storeman_is_active())
                    AND (
                        (SELECT public.storeman_is_admin())
                        OR
                        warehouse_id =
                        (SELECT public.storeman_current_warehouse_id())
                    )
                )
                WITH CHECK (
                    (SELECT public.storeman_is_active())
                    AND (
                        (SELECT public.storeman_is_admin())
                        OR
                        warehouse_id =
                        (SELECT public.storeman_current_warehouse_id())
                    )
                )
                $p$,
                t
            );

        END IF;

    END LOOP;

END $$;


-- ============================================================
-- 12. WAREHOUSES
-- ============================================================

DO $$
BEGIN

    IF to_regclass('public.warehouses') IS NULL THEN
        RETURN;
    END IF;

    EXECUTE $p$
        DROP POLICY IF EXISTS storeman_warehouse_select
        ON public.warehouses
    $p$;

    EXECUTE $p$
        CREATE POLICY storeman_warehouse_select
        ON public.warehouses
        FOR SELECT
        TO authenticated
        USING (
            (SELECT public.storeman_is_active())
            AND (
                id =
                (SELECT public.storeman_current_warehouse_id())
                OR
                company_id =
                (SELECT public.storeman_current_company_id())
                AND
                (SELECT public.storeman_is_admin())
            )
        )
    $p$;

END $$;


-- ============================================================
-- 13. COMPANIES
-- ============================================================

DO $$
BEGIN

    IF to_regclass('public.companies') IS NULL THEN
        RETURN;
    END IF;

    EXECUTE $p$
        DROP POLICY IF EXISTS storeman_companies_select
        ON public.companies
    $p$;

    EXECUTE $p$
        CREATE POLICY storeman_companies_select
        ON public.companies
        FOR SELECT
        TO authenticated
        USING (
            (SELECT public.storeman_is_active())
            AND (
                id =
                (SELECT public.storeman_current_company_id())
                OR
                (SELECT public.storeman_is_admin())
            )
        )
    $p$;

END $$;


-- ============================================================
-- 14. ACTIVITY LOGS
-- ============================================================

DO $$
BEGIN

    IF to_regclass('public.activity_logs') IS NULL THEN
        RETURN;
    END IF;

    -- Users can see their own activity.
    -- Admin/Owner can see company activity.

    EXECUTE $p$
        DROP POLICY IF EXISTS storeman_activity_select
        ON public.activity_logs
    $p$;

    EXECUTE $p$
        CREATE POLICY storeman_activity_select
        ON public.activity_logs
        FOR SELECT
        TO authenticated
        USING (
            user_id = (SELECT auth.uid())
            OR
            (
                company_id =
                (SELECT public.storeman_current_company_id())
                AND
                (SELECT public.storeman_is_admin())
            )
        )
    $p$;

    EXECUTE $p$
        DROP POLICY IF EXISTS storeman_activity_insert
        ON public.activity_logs
    $p$;

    EXECUTE $p$
        CREATE POLICY storeman_activity_insert
        ON public.activity_logs
        FOR INSERT
        TO authenticated
        WITH CHECK (
            user_id = (SELECT auth.uid())
            AND
            company_id =
            (SELECT public.storeman_current_company_id())
        )
    $p$;

END $$;


-- ============================================================
-- 15. USER PERMISSIONS
-- ============================================================

DO $$
BEGIN

    IF to_regclass('public.user_permissions') IS NULL THEN
        RETURN;
    END IF;

    -- Only admin/owner should see/manage permission rows.

    EXECUTE $p$
        DROP POLICY IF EXISTS storeman_user_permissions_admin
        ON public.user_permissions
    $p$;

    EXECUTE $p$
        CREATE POLICY storeman_user_permissions_admin
        ON public.user_permissions
        FOR ALL
        TO authenticated
        USING (
            (SELECT public.storeman_is_admin())
        )
        WITH CHECK (
            (SELECT public.storeman_is_admin())
        )
    $p$;

END $$;


-- ============================================================
-- 16. INDEXES
-- ============================================================

DO $$
DECLARE
    t text;
BEGIN

    FOREACH t IN ARRAY ARRAY[
        'materials',
        'transactions',
        'sales_orders',
        'store_backups',
        'warehouses',
        'suppliers',
        'customers',
        'invoices',
        'activity_logs'
    ]
    LOOP

        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema='public'
            AND table_name=t
            AND column_name='company_id'
        ) THEN

            EXECUTE format(
                'CREATE INDEX IF NOT EXISTS %I ON public.%I(company_id)',
                'idx_' || t || '_company_id',
                t
            );

        END IF;

        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema='public'
            AND table_name=t
            AND column_name='warehouse_id'
        ) THEN

            EXECUTE format(
                'CREATE INDEX IF NOT EXISTS %I ON public.%I(warehouse_id)',
                'idx_' || t || '_warehouse_id',
                t
            );

        END IF;

    END LOOP;

END $$;


-- ============================================================
-- 17. SECURITY CHECK
-- ============================================================

SELECT
    n.nspname AS schema_name,
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled,
    c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n
    ON n.oid=c.relnamespace
WHERE n.nspname='public'
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
ORDER BY c.relname;


SELECT
    schemaname,
    tablename,
    policyname,
    cmd,
    permissive
FROM pg_policies
WHERE schemaname='public'
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
ORDER BY tablename, policyname;


SELECT
    'STOREMAN SECURITY RLS MASTER COMPLETE'
    AS status;
