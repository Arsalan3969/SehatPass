-- ==============================================================================
-- SehatPass Migration: Patient App Functionality Audit & Schema Hardening
-- ==============================================================================
-- 1. Create public.sehat_ai_conversations table for multi-chat support
-- 2. Add conversation_id to public.sehat_ai_chats
-- 3. Add start_date to public.patient_medicines
-- 4. Add is_active to public.emergency_settings
-- 5. Harden get_public_emergency_info RPC function
-- 6. Enforce RLS and grant authenticated role least-privilege permissions
-- ==============================================================================

-- 1. Create public.sehat_ai_conversations
CREATE TABLE IF NOT EXISTS public.sehat_ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'New Conversation',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast user conversation queries
CREATE INDEX IF NOT EXISTS idx_sehat_ai_conversations_user_id
ON public.sehat_ai_conversations (user_id, updated_at DESC);

-- 2. Add conversation_id column to public.sehat_ai_chats
ALTER TABLE public.sehat_ai_chats
ADD COLUMN IF NOT EXISTS conversation_id UUID NULL REFERENCES public.sehat_ai_conversations(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_sehat_ai_chats_conversation_id
ON public.sehat_ai_chats (conversation_id, created_at ASC);

-- 3. Add start_date to public.patient_medicines
ALTER TABLE public.patient_medicines
ADD COLUMN IF NOT EXISTS start_date DATE NOT NULL DEFAULT CURRENT_DATE;

-- 4. Add is_active to public.emergency_settings
ALTER TABLE public.emergency_settings
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 5. Enable RLS on sehat_ai_conversations
ALTER TABLE public.sehat_ai_conversations ENABLE ROW LEVEL SECURITY;

-- Revoke default public / anon access
REVOKE ALL ON public.sehat_ai_conversations FROM PUBLIC, anon;

-- Grant authenticated role permissions for conversations
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.sehat_ai_conversations TO authenticated;

-- Policies for sehat_ai_conversations
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'sehat_ai_conversations'
          AND policyname = 'Patients can manage their own conversations'
    ) THEN
        CREATE POLICY "Patients can manage their own conversations"
        ON public.sehat_ai_conversations
        FOR ALL
        TO authenticated
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

-- 6. Update get_public_emergency_info RPC function
CREATE OR REPLACE FUNCTION public.get_public_emergency_info(p_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'is_active', e.is_active,
    'full_name', CASE WHEN e.share_name THEN p.full_name ELSE NULL END,
    'date_of_birth', CASE WHEN e.share_name THEN pp.date_of_birth ELSE NULL END,
    'gender', CASE WHEN e.share_name THEN pp.gender ELSE NULL END,
    'blood_group', CASE WHEN e.share_blood_group THEN pp.blood_group ELSE NULL END,
    'allergies', CASE WHEN e.share_allergies THEN pp.allergies ELSE NULL END,
    'medical_conditions', CASE WHEN e.share_medical_conditions THEN pp.medical_conditions ELSE NULL END,
    'important_medicines', CASE WHEN e.share_important_medicines THEN (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'name', m.name,
        'dosage', m.dosage,
        'instruction', m.instruction,
        'scheduled_time', m.scheduled_time
      )), '[]'::jsonb)
      FROM public.patient_medicines m
      WHERE m.patient_id = e.patient_id AND m.is_active = true
    ) ELSE '[]'::jsonb END,
    'emergency_contact', CASE WHEN e.share_emergency_contact THEN jsonb_build_object(
      'name', e.contact_name,
      'relationship', e.contact_relationship,
      'phone', e.contact_phone
    ) ELSE NULL END,
    'updated_at', e.updated_at
  ) INTO v_result
  FROM public.emergency_settings e
  JOIN public.profiles p ON p.id = e.patient_id
  LEFT JOIN public.patient_profiles pp ON pp.patient_id = e.patient_id
  WHERE e.emergency_token = p_token
    AND e.is_active = true;

  RETURN v_result;
END;
$$;

-- Grant EXECUTE permission on get_public_emergency_info to anon and authenticated
GRANT EXECUTE ON FUNCTION public.get_public_emergency_info(uuid) TO anon, authenticated;
