-- ==============================================================================
-- SehatPass Migration: Emergency QR Medical Reports Support
-- ==============================================================================
-- 1. Updates get_public_emergency_info RPC to include authorized patient medical reports
-- 2. Scoped strictly to the patient resolved from the valid emergency_token (e.patient_id)
-- 3. Does NOT accept patient_id from client
-- 4. Exposes only safe report metadata (id, title, lab_facility, report_date, category,
--    storage_file_path, file_name, file_size_bytes, mime_type)
-- 5. Does NOT expose extracted_text, raw OCR, or AI summaries
-- 6. Preserves private storage bucket medical-reports and all existing RLS policies
-- ==============================================================================

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
    'medical_reports', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', mr.id,
        'title', mr.title,
        'lab_facility', mr.lab_facility,
        'report_date', mr.report_date,
        'category', mr.category,
        'storage_file_path', mr.storage_file_path,
        'file_name', mr.file_name,
        'file_size_bytes', mr.file_size_bytes,
        'mime_type', mr.mime_type
      ) ORDER BY mr.report_date DESC NULLS LAST, mr.created_at DESC), '[]'::jsonb)
      FROM public.medical_reports mr
      WHERE mr.patient_id = e.patient_id
    ),
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
