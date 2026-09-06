-- ==============================================================================
-- SehatPass Migration: Patient In-App Notifications Schema (Phase 2A)
-- ==============================================================================
-- 1. Create public.notifications table with strict foreign key binding to public.profiles(id)
-- 2. Performance indexes for user inbox queries, unread filtering, and chronological sorting
-- 3. Automatic updated_at trigger
-- 4. Strict Row Level Security (RLS) policies scoped exclusively to authenticated user (auth.uid())
-- 5. Least-privilege grants (No anon privileges, authenticated SELECT/UPDATE/INSERT)
-- ==============================================================================

-- 1. Create public.notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'system',
    is_read BOOLEAN NOT NULL DEFAULT false,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ensure columns exist if table was partially created
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'system';
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS payload JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Ensure payload is valid JSON object
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS chk_notifications_payload_is_object;
ALTER TABLE public.notifications ADD CONSTRAINT chk_notifications_payload_is_object
    CHECK (jsonb_typeof(payload) = 'object');

-- 2. Indexes for fast user querying, filtering, and sorting
CREATE INDEX IF NOT EXISTS idx_notifications_user_id
    ON public.notifications (user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id_is_read
    ON public.notifications (user_id, is_read);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id_created_at
    ON public.notifications (user_id, created_at DESC);

-- 3. Automatic updated_at trigger
CREATE OR REPLACE FUNCTION public.handle_notifications_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notifications_updated_at ON public.notifications;
CREATE TRIGGER trg_notifications_updated_at
    BEFORE UPDATE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_notifications_updated_at();

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Revoke default public and anon access
REVOKE ALL ON public.notifications FROM PUBLIC, anon;

-- Grant least-privilege authenticated role access
GRANT SELECT, INSERT, UPDATE ON TABLE public.notifications TO authenticated;

-- RLS Policies: Authenticated users can only read their own notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
CREATE POLICY "Users can view their own notifications"
    ON public.notifications
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- RLS Policies: Authenticated users can only update their own notifications (e.g. mark as read)
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
    ON public.notifications
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- RLS Policies: Authenticated users can insert notifications scoped to themselves (or system functions)
DROP POLICY IF EXISTS "Users can insert their own notifications" ON public.notifications;
CREATE POLICY "Users can insert their own notifications"
    ON public.notifications
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());
