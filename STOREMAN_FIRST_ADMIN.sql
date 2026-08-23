-- ============================================================
-- STOREMAN FIRST ADMIN
-- ============================================================
--
-- IMPORTANT:
-- First create the user in:
--
-- Supabase Dashboard
-- → Authentication
-- → Users
-- → Add user
--
-- Then replace ADMIN_EMAIL below with that exact email.
--
-- ============================================================

DO $$
DECLARE
    admin_user_id uuid;
    main_company_id uuid;
BEGIN

    SELECT id
    INTO admin_user_id
    FROM auth.users
    WHERE lower(email) = lower('ADMIN_EMAIL');

    IF admin_user_id IS NULL THEN
        RAISE EXCEPTION
        'Admin Auth user not found. Create the user in Supabase Authentication first.';
    END IF;

    SELECT id
    INTO main_company_id
    FROM public.companies
    WHERE slug = 'storeman-main'
    LIMIT 1;

    IF main_company_id IS NULL THEN
        RAISE EXCEPTION
        'Storeman Main Company was not found.';
    END IF;

    INSERT INTO public.profiles (
        id,
        company_id,
        role,
        status,
        permissions
    )
    VALUES (
        admin_user_id,
        main_company_id,
        'admin',
        'active',
        '{}'::jsonb
    )
    ON CONFLICT (id)
    DO UPDATE SET
        company_id = EXCLUDED.company_id,
        role = 'admin',
        status = 'active',
        permissions = '{}'::jsonb;

END $$;

SELECT
    p.id,
    p.company_id,
    p.role,
    p.status,
    u.email
FROM public.profiles p
JOIN auth.users u
    ON u.id = p.id
WHERE lower(u.email) = lower('ADMIN_EMAIL');
