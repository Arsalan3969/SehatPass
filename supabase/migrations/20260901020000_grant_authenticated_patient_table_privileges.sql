-- ==============================================================================
-- SehatPass Migration: Grant Minimum Required Privileges to Authenticated Role
-- ==============================================================================
-- Security Guardrails:
-- 1. Zero privileges granted to 'anon' or 'public'.
-- 2. Row Level Security (RLS) remains strictly enabled on all tables.
-- 3. All client access constrained to patient_id / user_id = auth.uid().
-- 4. Minimum necessary privileges per repository requirement.
-- ==============================================================================

-- 1. Medical Reports (Flutter: load, upload, delete, update)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.medical_reports TO authenticated;

-- 2. Patient Medicines (Flutter: load, add, update, deactivate, delete)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.patient_medicines TO authenticated;

-- 3. Medicine Dose Logs (Flutter: dose schedule tracking, mark taken)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.medicine_dose_logs TO authenticated;

-- 4. Sehat AI Chats (Flutter: load history, clear history; AI inserts via service_role)
GRANT SELECT, DELETE ON TABLE public.sehat_ai_chats TO authenticated;

-- 5. Doctor Consultation Notes (Edge Function user client: patient context read only)
GRANT SELECT ON TABLE public.doctor_consultation_notes TO authenticated;
