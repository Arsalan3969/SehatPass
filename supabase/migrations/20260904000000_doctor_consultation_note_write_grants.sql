-- ==============================================================================
-- SehatPass Migration: Doctor Consultation Notes Write Grants
-- Migration: 20260904000000_doctor_consultation_note_write_grants.sql
-- ==============================================================================
-- Grant table-level SELECT, INSERT, UPDATE privileges on public.doctor_consultation_notes
-- to the 'authenticated' role.
--
-- Security Rules Preserved:
-- 1. Zero DELETE privileges granted to authenticated or anon.
-- 2. PostgREST RLS and database triggers (validate_consultation_note_mutations)
--    continue to strictly enforce doctor-patient assignment, appointment lifecycle
--    status (confirmed/completed only), and immutable foreign keys.
-- 3. Patient role remains strictly read-only for own confirmed/completed consultations.
-- ==============================================================================

GRANT SELECT, INSERT, UPDATE ON TABLE public.doctor_consultation_notes TO authenticated;
