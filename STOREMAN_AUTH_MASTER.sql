
BEGIN;

-- ============================================================
-- STOREMAN FULL AUTH / ADMIN MASTER
-- ============================================================
-- Features:
-- Block / Unblock
-- Role management
-- Company assignment
-- Warehouse assignment
-- Permissions
-- Activity logs
-- Last login / Last seen
-- RLS
-- Secure admin RPC
-- Persistent login support
-- ============================================================


-- ============================================================
-- 1. PROFILES SCHEMA
-- ============================================================

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS company_id uuid,
    ADD COLUMN IF NOT EXISTS warehouse_id uuid,
    ADD COLUMN IF NOT EXISTS role text,
    ADD COLUMN IF NOT EXISTS status text DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS permissions jsonb DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS last_login_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;


-- ============================================================
-- 2. SAFE DEFAULTS
-- ============================================================

UPDATE public.profiles
SET status = 'active'
WHERE status IS NULL;

UPDATE public.profiles
SET role = 'user'
WHERE role IS NULL;

UPDATE public.profiles
SET permissions = '{}'::jsonb
WHERE permissions IS NULL;


-- ============================================================
-- 3. ROLE CHECK
-- ============================================================

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_role_check
CHECK (
    lower(role) IN (
        'owner',
        'admin',
        'manager',
        'staff',
        'user'
    )
);


-- ============================================================
-- 4. STATUS CHECK
-- ============================================================

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_status_check;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_status_check
CHECK (
    lower(status) IN (
        'active',
        'blocked',
        'disabled',
        'suspended'
    )
);


-- ============================================================
-- 5. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS profiles_company_id_idx
ON public.profiles(company_id);

CREATE INDEX IF NOT EXISTS profiles_status_idx
ON public.profiles(status);

CREATE INDEX IF NOT EXISTS profiles_role_idx
ON public.profiles(role);

CREATE INDEX IF NOT EXISTS profiles_last_seen_idx
ON public.profiles(last_seen_at DESC);


-- ============================================================
-- 6. SECURITY DEFINER HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.storeman_profile(
    uid uuid DEFAULT auth.uid()
)
RETURNS public.profiles
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT p
    FROM public.profiles p
    WHERE p.id = uid
    LIMIT 1;
$$;


-- ============================================================
-- 7. CURRENT COMPANY
-- ============================================================

CREATE OR REPLACE FUNCTION public.current_company_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT company_id
    FROM public.profiles
    WHERE id = auth.uid()
    LIMIT 1;
$$;


-- ============================================================
-- 8. ADMIN CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid()
        AND lower(role) IN ('admin','owner')
        AND lower(status) = 'active'
    );
$$;


-- ============================================================
-- 9. OWNER CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_owner()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid()
        AND lower(role) = 'owner'
        AND lower(status) = 'active'
    );
$$;


-- ============================================================
-- 10. PERMISSION CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_permission(
    feature_name text,
    action_name text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT
        CASE
            WHEN lower(role) IN ('admin','owner')
                THEN true

            ELSE COALESCE(
                permissions -> feature_name ->> action_name,
                'false'
            )::boolean
        END
    FROM public.profiles
    WHERE id = auth.uid()
    AND lower(status) = 'active'
    LIMIT 1;
$$;


-- ============================================================
-- 11. ADMIN LIST USERS
-- ============================================================
-- IMPORTANT:
-- email is NOT read from profiles.
-- email comes from auth.users.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE (
    id uuid,
    email text,
    full_name text,
    role text,
    status text,
    company_id uuid,
    company_name text,
    warehouse_id uuid,
    warehouse_name text,
    permissions jsonb,
    last_login_at timestamptz,
    last_seen_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    caller_company uuid;
BEGIN

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required';
    END IF;

    caller_company := public.current_company_id();

    RETURN QUERY
    SELECT
        p.id,
        u.email::text,
        COALESCE(
            p.full_name,
            u.raw_user_meta_data ->> 'full_name'
        )::text AS full_name,
        p.role,
        p.status,
        p.company_id,
        c.name AS company_name,
        p.warehouse_id,
        w.name AS warehouse_name,
        p.permissions,
        p.last_login_at,
        p.last_seen_at
    FROM public.profiles p
    JOIN auth.users u
        ON u.id = p.id
    LEFT JOIN public.companies c
        ON c.id = p.company_id
    LEFT JOIN public.warehouses w
        ON w.id = p.warehouse_id
    WHERE p.company_id = caller_company
    ORDER BY p.last_seen_at DESC NULLS LAST;

END;
$$;


-- ============================================================
-- 12. LIST COMPANIES
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_list_companies()
RETURNS TABLE (
    id uuid,
    name text,
    slug text,
    status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required';
    END IF;

    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.slug,
        c.status
    FROM public.companies c
    ORDER BY c.name;

END;
$$;


-- ============================================================
-- 13. LIST WAREHOUSES
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_list_warehouses(
    target_company_id uuid DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    name text,
    company_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    cid uuid;
BEGIN

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required';
    END IF;

    cid := COALESCE(
        target_company_id,
        public.current_company_id()
    );

    RETURN QUERY
    SELECT
        w.id,
        w.name,
        w.company_id
    FROM public.warehouses w
    WHERE w.company_id = cid
    ORDER BY w.name;

END;
$$;


-- ============================================================
-- 14. BLOCK / UNBLOCK USER
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_set_user_status(
    target_user_id uuid,
    new_status text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_company uuid;
    target_company uuid;
BEGIN

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required';
    END IF;

    IF new_status NOT IN (
        'active',
        'blocked',
        'disabled',
        'suspended'
    ) THEN
        RAISE EXCEPTION 'Invalid user status';
    END IF;

    IF target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Administrator cannot block itself';
    END IF;

    caller_company := public.current_company_id();

    SELECT company_id
    INTO target_company
    FROM public.profiles
    WHERE id = target_user_id;

    IF target_company IS NULL THEN
        RAISE EXCEPTION 'Target user profile not found';
    END IF;

    IF target_company <> caller_company THEN
        RAISE EXCEPTION 'User belongs to another company';
    END IF;

    UPDATE public.profiles
    SET
        status = new_status,
        last_seen_at = now()
    WHERE id = target_user_id;

    INSERT INTO public.activity_logs (
        user_id,
        company_id,
        action,
        table_name,
        record_id,
        details
    )
    VALUES (
        auth.uid(),
        caller_company,
        upper(new_status),
        'profiles',
        target_user_id,
        jsonb_build_object(
            'source',
            'storeman-admin',
            'target_user',
            target_user_id
        )
    );

    RETURN true;

END;
$$;


-- ============================================================
-- 15. ROLE MANAGEMENT
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_set_user_role(
    target_user_id uuid,
    new_role text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_company uuid;
    target_company uuid;
    caller_role text;
    target_role text;
BEGIN

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required';
    END IF;

    new_role := lower(new_role);

    IF new_role NOT IN (
        'owner',
        'admin',
        'manager',
        'staff',
        'user'
    ) THEN
        RAISE EXCEPTION 'Invalid role';
    END IF;

    IF target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Administrator cannot change its own role';
    END IF;

    SELECT company_id, role
    INTO caller_company, caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    SELECT company_id, role
    INTO target_company, target_role
    FROM public.profiles
    WHERE id = target_user_id;

    IF target_company IS NULL THEN
        RAISE EXCEPTION 'Target user profile not found';
    END IF;

    IF target_company <> caller_company THEN
        RAISE EXCEPTION 'User belongs to another company';
    END IF;

    -- Only owner can create/change owner/admin roles.
    IF new_role IN ('owner','admin')
       AND lower(caller_role) <> 'owner' THEN
        RAISE EXCEPTION 'Only owner can assign owner/admin roles';
    END IF;

    -- Only owner can change an existing owner.
    IF lower(target_role) = 'owner'
       AND lower(caller_role) <> 'owner' THEN
        RAISE EXCEPTION 'Only owner can modify owner';
    END IF;

    UPDATE public.profiles
    SET role = new_role
    WHERE id = target_user_id;

    INSERT INTO public.activity_logs (
        user_id,
        company_id,
        action,
        table_name,
        record_id,
        details
    )
    VALUES (
        auth.uid(),
        caller_company,
        'ROLE_CHANGED',
        'profiles',
        target_user_id,
        jsonb_build_object(
            'new_role',
            new_role
        )
    );

    RETURN true;

END;
$$;


-- ============================================================
-- 16. COMPANY ASSIGNMENT
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_assign_company(
    target_user_id uuid,
    target_company_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_company uuid;
BEGIN

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required';
    END IF;

    IF NOT public.is_owner() THEN
        RAISE EXCEPTION 'Only owner can change company assignment';
    END IF;

    IF target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot change own company';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.companies
        WHERE id = target_company_id
    ) THEN
        RAISE EXCEPTION 'Company not found';
    END IF;

    SELECT company_id
    INTO caller_company
    FROM public.profiles
    WHERE id = auth.uid();

    UPDATE public.profiles
    SET
        company_id = target_company_id,
        warehouse_id = NULL
    WHERE id = target_user_id;

    INSERT INTO public.activity_logs (
        user_id,
        company_id,
        action,
        table_name,
        record_id,
        details
    )
    VALUES (
        auth.uid(),
        caller_company,
        'COMPANY_CHANGED',
        'profiles',
        target_user_id,
        jsonb_build_object(
            'new_company',
            target_company_id
        )
    );

    RETURN true;

END;
$$;


-- ============================================================
-- 17. WAREHOUSE ASSIGNMENT
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_assign_warehouse(
    target_user_id uuid,
    target_warehouse_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_company uuid;
    target_company uuid;
    warehouse_company uuid;
BEGIN

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required';
    END IF;

    caller_company := public.current_company_id();

    SELECT company_id
    INTO target_company
    FROM public.profiles
    WHERE id = target_user_id;

    SELECT company_id
    INTO warehouse_company
    FROM public.warehouses
    WHERE id = target_warehouse_id;

    IF target_company IS NULL THEN
        RAISE EXCEPTION 'Target user profile not found';
    END IF;

    IF warehouse_company IS NULL THEN
        RAISE EXCEPTION 'Warehouse not found';
    END IF;

    IF target_company <> caller_company
       OR warehouse_company <> caller_company THEN
        RAISE EXCEPTION 'Company mismatch';
    END IF;

    UPDATE public.profiles
    SET warehouse_id = target_warehouse_id
    WHERE id = target_user_id;

    INSERT INTO public.activity_logs (
        user_id,
        company_id,
        action,
        table_name,
        record_id,
        details
    )
    VALUES (
        auth.uid(),
        caller_company,
        'WAREHOUSE_CHANGED',
        'profiles',
        target_user_id,
        jsonb_build_object(
            'warehouse_id',
            target_warehouse_id
        )
    );

    RETURN true;

END;
$$;


-- ============================================================
-- 18. PERMISSION MANAGEMENT
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_set_user_permissions(
    target_user_id uuid,
    new_permissions jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_company uuid;
    target_company uuid;
BEGIN

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required';
    END IF;

    caller_company := public.current_company_id();

    SELECT company_id
    INTO target_company
    FROM public.profiles
    WHERE id = target_user_id;

    IF target_company IS NULL THEN
        RAISE EXCEPTION 'Target user not found';
    END IF;

    IF target_company <> caller_company THEN
        RAISE EXCEPTION 'Company mismatch';
    END IF;

    UPDATE public.profiles
    SET permissions = COALESCE(
        new_permissions,
        '{}'::jsonb
    )
    WHERE id = target_user_id;

    INSERT INTO public.activity_logs (
        user_id,
        company_id,
        action,
        table_name,
        record_id,
        details
    )
    VALUES (
        auth.uid(),
        caller_company,
        'PERMISSIONS_CHANGED',
        'profiles',
        target_user_id,
        jsonb_build_object(
            'permissions',
            new_permissions
        )
    );

    RETURN true;

END;
$$;


-- ============================================================
-- 19. PROFILES RLS
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select_policy
ON public.profiles;

DROP POLICY IF EXISTS profiles_update_policy
ON public.profiles;

CREATE POLICY profiles_select_policy
ON public.profiles
FOR SELECT
TO authenticated
USING (
    id = auth.uid()
    OR (
        public.is_admin()
        AND company_id = public.current_company_id()
    )
);


CREATE POLICY profiles_update_policy
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    id = auth.uid()
    OR (
        public.is_admin()
        AND company_id = public.current_company_id()
    )
)
WITH CHECK (
    id = auth.uid()
    OR (
        public.is_admin()
        AND company_id = public.current_company_id()
    )
);


-- ============================================================
-- 20. ACTIVITY LOG RLS
-- ============================================================

ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS activity_logs_select_policy
ON public.activity_logs;

DROP POLICY IF EXISTS activity_logs_insert_policy
ON public.activity_logs;


CREATE POLICY activity_logs_select_policy
ON public.activity_logs
FOR SELECT
TO authenticated
USING (
    company_id = public.current_company_id()
    AND public.is_admin()
);


CREATE POLICY activity_logs_insert_policy
ON public.activity_logs
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = public.current_company_id()
    AND user_id = auth.uid()
);


-- ============================================================
-- 21. COMPANY-BASED RLS FOR MAIN STOREMAN TABLES
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
        'invoices'
    ]
    LOOP

        IF to_regclass('public.' || t) IS NOT NULL THEN

            EXECUTE format(
                'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
                t
            );

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
                'CREATE POLICY storeman_company_select
                 ON public.%I
                 FOR SELECT
                 TO authenticated
                 USING (company_id = public.current_company_id())',
                t
            );

            EXECUTE format(
                'CREATE POLICY storeman_company_insert
                 ON public.%I
                 FOR INSERT
                 TO authenticated
                 WITH CHECK (company_id = public.current_company_id())',
                t
            );

            EXECUTE format(
                'CREATE POLICY storeman_company_update
                 ON public.%I
                 FOR UPDATE
                 TO authenticated
                 USING (company_id = public.current_company_id())
                 WITH CHECK (company_id = public.current_company_id())',
                t
            );

            EXECUTE format(
                'CREATE POLICY storeman_company_delete
                 ON public.%I
                 FOR DELETE
                 TO authenticated
                 USING (company_id = public.current_company_id())',
                t
            );

        END IF;

    END LOOP;

END $$;


-- ============================================================
-- 22. RPC PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.admin_list_users()
TO authenticated;

GRANT EXECUTE ON FUNCTION public.admin_list_companies()
TO authenticated;

GRANT EXECUTE ON FUNCTION public.admin_list_warehouses(uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.admin_set_user_status(uuid,text)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid,text)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.admin_assign_company(uuid,uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.admin_assign_warehouse(uuid,uuid)
TO authenticated;

GRANT EXECUTE ON FUNCTION public.admin_set_user_permissions(uuid,jsonb)
TO authenticated;


-- ============================================================
-- 23. FINAL VERIFICATION
-- ============================================================

SELECT
    p.id,
    u.email,
    p.role,
    p.status,
    p.company_id,
    p.warehouse_id,
    p.last_login_at,
    p.last_seen_at,
    p.permissions
FROM public.profiles p
LEFT JOIN auth.users u
    ON u.id = p.id
ORDER BY p.role, u.email;


COMMIT;

SELECT 'STOREMAN AUTH MASTER INSTALLED' AS status;

