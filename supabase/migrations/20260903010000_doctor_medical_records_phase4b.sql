-- ==============================================================================
-- SehatPass Migration: Doctor Medical Records & Active Medicines (Phase 4B)
-- ==============================================================================
-- 1. Grant authenticated SELECT on public.patient_medicines and public.medical_reports
-- 2. Enforce strict appointment-scoped RLS policies:
--    - Doctors can SELECT active medicines and report metadata ONLY when:
--        a. Caller is a verified doctor (doctor_profiles.doctor_id = auth.uid())
--        b. An appointment exists linking doctor and patient with status
--           IN ('confirmed', 'completed')  [NOTE: 'pending' is DENIED for sensitive medical data]
--    - Patients retain full CRUD on their own records (patient_id = auth.uid())
-- 3. Storage RLS on `medical-reports` private bucket:
--    - Scoped by patient UUID folder prefix `(storage.foldername(name))[1]`
--    - Doctors can read files ONLY for confirmed or completed appointments
-- 4. Minimum least-privilege grants (zero doctor mutations on patient clinical data)
-- ==============================================================================

-- 1. Ensure RLS is active on clinical tables
ALTER TABLE IF EXISTS public.patient_medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.medical_reports ENABLE ROW LEVEL SECURITY;

-- 2. Patient Medicines: Doctor Read-Only Policy
DROP POLICY IF EXISTS "Doctors can view medicines of assigned patients" ON public.patient_medicines;
CREATE POLICY "Doctors can view medicines of assigned patients"
ON public.patient_medicines
FOR SELECT
TO authenticated
USING (
    -- Caller must be an active doctor
    EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = auth.uid()
    )
    -- Must have a confirmed or completed appointment (pending is excluded for medical sensitivity)
    AND EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.patient_id = patient_medicines.patient_id
          AND a.doctor_id = auth.uid()
          AND a.status IN ('confirmed', 'completed')
    )
);

-- 3. Medical Reports: Doctor Read-Only Policy
DROP POLICY IF EXISTS "Doctors can view medical reports of assigned patients" ON public.medical_reports;
CREATE POLICY "Doctors can view medical reports of assigned patients"
ON public.medical_reports
FOR SELECT
TO authenticated
USING (
    -- Caller must be an active doctor
    EXISTS (
        SELECT 1 FROM public.doctor_profiles dp
        WHERE dp.doctor_id = auth.uid()
    )
    -- Must have a confirmed or completed appointment
    AND EXISTS (
        SELECT 1 FROM public.appointments a
        WHERE a.patient_id = medical_reports.patient_id
          AND a.doctor_id = auth.uid()
          AND a.status IN ('confirmed', 'completed')
    )
);

-- 4. Storage Objects: Doctor File Read Policy on private bucket `medical-reports`
DROP POLICY IF EXISTS "Doctors can read report files of assigned patients" ON storage.objects;
CREATE POLICY "Doctors can read report files of assigned patients"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'medical-reports'
    AND (
        -- Patient can access their own folder
        (storage.foldername(name))[1] = auth.uid()::text
        -- OR Assigned Doctor via confirmed or completed appointment
        OR (
            EXISTS (
                SELECT 1 FROM public.doctor_profiles dp
                WHERE dp.doctor_id = auth.uid()
            )
            AND EXISTS (
                SELECT 1 FROM public.appointments a
                WHERE a.patient_id::text = (storage.foldername(name))[1]
                  AND a.doctor_id = auth.uid()
                  AND a.status IN ('confirmed', 'completed')
            )
        )
    )
);

-- 5. Explicit table privilege grants to authenticated role
GRANT SELECT ON TABLE public.patient_medicines TO authenticated;
GRANT SELECT ON TABLE public.medical_reports TO authenticated;
GRANT ALL ON TABLE public.patient_medicines TO service_role;
GRANT ALL ON TABLE public.medical_reports TO service_role;
