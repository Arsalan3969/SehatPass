# SehatPass Supabase Integration Architecture & Database Plan

This document outlines the complete database schema, authentication flow, Row Level Security (RLS) policies, storage design, and Flutter integration roadmap for the SehatPass application.

---

## Table of Contents
1. [A. Current Project Architecture](#a-current-project-architecture)
2. [B. Proposed Supabase Architecture](#b-proposed-supabase-architecture)
3. [C. Database ERD-Style Relationship Diagram](#c-database-erd-style-relationship-diagram)
4. [D. Complete Table List](#d-complete-table-list)
5. [E. Columns and Schema for Every Table](#e-columns-and-schema-for-every-table)
6. [F. Foreign-Key Relationships](#f-foreign-key-relationships)
7. [G. RLS & Security Strategy](#g-rls--security-strategy)
8. [H. Authentication & Role Flow](#h-authentication--role-flow)
9. [I. Flutter ↔ Supabase Integration Plan](#i-flutter--supabase-integration-plan)
10. [J. Migration & Implementation Order](#j-migration--implementation-order)

---

## A. Current Project Architecture

### 1. File & Directory Layout
```
lib/
├── main.dart                          # App entry point, dotenv & Supabase.initialize()
├── app/
│   └── app_shell.dart                 # Patient 5-tab shell (Home, Reports, Medicines, Sehat AI, Profile)
├── core/
│   ├── constants/dummy_data.dart      # In-memory mock data (DummyMedicine, DummyReport, ReportItem)
│   └── theme/                         # AppColors, AppTheme, AppTextStyles
├── features/
│   ├── home/                          # Patient home dashboard overview
│   ├── reports/                       # Medical reports listing with category filter chips
│   ├── medicines/                     # Today's medicines schedule, status (taken/upcoming/missed), dose tracking
│   ├── sehat_ai/                      # AI assistant chat interface and quick action chips
│   ├── emergency_qr/                  # Emergency QR generation, privacy toggle management, preview
│   ├── appointments/                  # Doctor discovery, booking, review, mock payment, history
│   ├── doctor/                        # Doctor Portal:
│   │   ├── doctor_shell_screen.dart   # Doctor 5-tab shell (Dashboard, Appointments, Patients, Clinic, Profile)
│   │   ├── onboarding/                # 5-step clinic & profile onboarding flow
│   │   ├── dashboard/                 # Doctor analytics, quick actions, schedule
│   │   ├── appointments/              # Doctor appointment request management (accept, decline, complete)
│   │   ├── patients/                  # Doctor's patient list & comprehensive patient clinical record view
│   │   ├── clinic/                    # Clinic details, services pricing, consultation availability
│   │   └── profile/                   # Doctor credentials, bio, qualifications, settings
│   └── profile/                       # Patient profile view, emergency info, doctor portal entry
└── shared/
    └── widgets/                       # AppCard, SectionHeader, reusable UI components
```

### 2. Current State Management & Persistence
* **In-Memory Singletons**: `AppointmentRepository.instance` and `EmergencyInfoRepository.instance` use `ChangeNotifier` with local lists.
* **Direct UI State**: Screens like `MedicinesScreen`, `ReportsScreen`, and `DoctorShellScreen` mutate local widget state and dummy arrays.
* **No Authentication Guard**: The app boots directly into `AppShell` (patient view) without session inspection or role dispatching.

---

## B. Proposed Supabase Architecture

The backend utilizes Supabase's three core services:
1. **Supabase Auth**: Manages user identity (email/password, OAuth) with user metadata (`role: 'patient' | 'doctor'`).
2. **Supabase Database (PostgreSQL)**: Multi-tenant relational schema partitioned by user roles with Row Level Security (RLS).
3. **Supabase Storage**:
   * `avatars` bucket (public read): Patient profile photos, Doctor profile photos, Clinic logos.
   * `medical-reports` bucket (private): High-resolution lab reports (PDF, PNG, JPEG), scan documents. Accessible only by the owning patient and authorized treating doctors.

### Evaluation of Existing `public.profiles` Table
Existing table and trigger setup:
```sql
public.profiles (
  id uuid primary key references auth.users(id),
  full_name text,
  email text,
  role text check (role in ('patient', 'doctor')),
  profile_photo_url text,
  created_at timestamptz,
  updated_at timestamptz
)
```
* **Verdict**: Keep `public.profiles` as the shared identity table.
* Role-specific tables (`patient_profiles` and `doctor_profiles`) extend this table via 1-to-1 relationships to isolate role-specific attributes cleanly.

---

## C. Database ERD-Style Relationship Diagram

```
                 auth.users
                     │ 1:1
                     ▼
              public.profiles (Shared Identity)
              ├── id (PK, UUID)
              ├── email
              ├── full_name
              ├── role ('patient' | 'doctor')
              └── profile_photo_url
                     │
         ┌───────────┴───────────┐
     1:1 │                       │ 1:1
         ▼                       ▼
  patient_profiles        doctor_profiles
  ├── patient_id (PK)     ├── doctor_id (PK)
  ├── date_of_birth       ├── specialization
  ├── gender              ├── qualifications
  ├── blood_group         ├── experience_years
  ├── allergies           ├── bio
  └── medical_conditions  ├── is_published
         │                └── rating
         │                       │ 1:1
         │                       ▼
         │                    clinics
         │                    ├── id (PK)
         │                    ├── doctor_id (FK)
         │                    ├── name, address, city
         │                    └── phone, description
         │                       │
         │           ┌───────────┴───────────┐
         │       1:N │                   1:N │
         │           ▼                       ▼
         │    clinic_services        doctor_availability
         │    ├── id (PK)            ├── id (PK)
         │    ├── clinic_id (FK)     ├── doctor_id (FK)
         │    ├── name               ├── day_of_week
         │    └── fee                ├── start_time
         │                           └── end_time
         │                                   │
         ├───────────────────────────────────┤
         │                                   │
         ▼ 1:N                               ▼ 1:N
   appointments ◄────────────────────────────┘
   ├── id (PK, UUID)
   ├── reference_no (e.g. SP-APT-0001)
   ├── patient_id (FK -> profiles.id)
   ├── doctor_id (FK -> profiles.id)
   ├── clinic_id (FK -> clinics.id)
   ├── service_id (FK -> clinic_services.id)
   ├── appointment_date
   ├── appointment_time
   ├── consultation_fee, platform_fee, total_amount
   ├── payment_status ('pending' | 'paid' | 'refunded')
   ├── payment_method ('card' | 'wallet' | 'cash')
   └── status ('pending' | 'confirmed' | 'completed' | 'cancelled')
         │
         │ (1:N Patient Data Tables)
         ├───────────────────────────────────────────┐
         ▼                                           ▼
  patient_medicines                           medical_reports
  ├── id (PK)                                 ├── id (PK)
  ├── patient_id (FK)                         ├── patient_id (FK)
  ├── name, dosage, instruction               ├── title, lab_name, report_date
  └── scheduled_time                          ├── category ('bloodTest'|'scan'|'other')
         │ 1:N                                └── storage_file_path (Bucket file)
         ▼
  medicine_dose_logs
  ├── id (PK)
  ├── medicine_id (FK)
  ├── dose_date
  └── status ('taken' | 'upcoming' | 'missed')

  emergency_settings
  ├── patient_id (PK)
  ├── contact_name, relationship, phone
  ├── share_name, share_blood_group, share_allergies, ...
  └── emergency_token (UUID for safe QR scanning)

  doctor_consultation_notes
  ├── id (PK)
  ├── appointment_id (FK)
  ├── doctor_id (FK), patient_id (FK)
  ├── diagnosis, notes, prescriptions (JSONB)
  └── created_at

  sehat_ai_chats
  ├── id (PK)
  ├── user_id (FK -> profiles.id)
  ├── sender ('user' | 'ai')
  ├── message
  └── created_at
```

---

## D. Complete Table List

1. `public.profiles` (Shared user identity)
2. `public.patient_profiles` (Patient medical profile)
3. `public.doctor_profiles` (Doctor credentials and listing data)
4. `public.clinics` (Clinic profile and contact information)
5. `public.clinic_services` (Services and consultation fees)
6. `public.doctor_availability` (Consultation schedule and working hours)
7. `public.appointments` (Booked appointments between patient and doctor)
8. `public.patient_medicines` (Prescribed medicines schedule)
9. `public.medicine_dose_logs` (Daily dose intake records)
10. `public.medical_reports` (Uploaded lab tests and diagnostic scans)
11. `public.emergency_settings` (Emergency contact and QR privacy flags)
12. `public.doctor_consultation_notes` (Doctor clinical notes per patient visit)
13. `public.sehat_ai_chats` (AI conversation history)

---

## E. Columns and Schema for Every Table

### 1. `public.profiles` (Existing)
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `auth.uid()` | Primary Key, references `auth.users(id)` |
| `email` | `text` | NO | — | User email address |
| `full_name` | `text` | NO | `''` | User full name |
| `role` | `text` | NO | `'patient'` | `'patient'` or `'doctor'` |
| `profile_photo_url` | `text` | YES | `NULL` | Public avatar URL |
| `created_at` | `timestamptz`| NO | `now()` | Registration timestamp |
| `updated_at` | `timestamptz`| NO | `now()` | Last modification timestamp |

### 2. `public.patient_profiles`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `patient_id` | `uuid` | NO | — | Primary Key, FK -> `profiles(id)` ON DELETE CASCADE |
| `date_of_birth` | `date` | YES | `NULL` | Patient date of birth |
| `gender` | `text` | YES | `NULL` | `'Male'`, `'Female'`, `'Other'` |
| `blood_group` | `text` | YES | `NULL` | `'O+'`, `'A+'`, `'B+'`, `'AB+'`, etc. |
| `allergies` | `text` | YES | `'None added'` | Known allergies |
| `medical_conditions` | `text`| YES | `'None added'` | Chronic conditions |
| `created_at` | `timestamptz`| NO | `now()` | Row creation timestamp |
| `updated_at` | `timestamptz`| NO | `now()` | Last update timestamp |

### 3. `public.doctor_profiles`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `doctor_id` | `uuid` | NO | — | Primary Key, FK -> `profiles(id)` ON DELETE CASCADE |
| `specialization` | `text` | NO | `'General Physician'` | e.g. 'Cardiologist', 'Dermatologist' |
| `qualifications` | `text` | NO | `'MBBS'` | e.g. 'MBBS, FCPS' |
| `experience_years` | `text` | NO | `'1 year'` | e.g. '8 years' |
| `bio` | `text` | YES | `NULL` | Doctor introduction |
| `rating` | `numeric(2,1)`| NO | `5.0` | Average patient rating |
| `total_reviews` | `int` | NO | `0` | Number of reviews |
| `is_published` | `boolean`| NO | `false` | Visible in patient doctor search |
| `created_at` | `timestamptz`| NO | `now()` | Timestamp |
| `updated_at` | `timestamptz`| NO | `now()` | Timestamp |

### 4. `public.clinics`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `doctor_id` | `uuid` | NO | — | FK -> `profiles(id)` ON DELETE CASCADE |
| `name` | `text` | NO | — | Clinic facility name |
| `address` | `text` | NO | — | Clinic street address |
| `city` | `text` | NO | `'Lahore'` | City location |
| `phone` | `text` | NO | — | Clinic phone number |
| `description` | `text` | YES | `NULL` | Overview description |
| `logo_url` | `text` | YES | `NULL` | Clinic logo storage URL |
| `is_active` | `boolean`| NO | `true` | Active listing status |
| `created_at` | `timestamptz`| NO | `now()` | Timestamp |
| `updated_at` | `timestamptz`| NO | `now()` | Timestamp |

### 5. `public.clinic_services`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `clinic_id` | `uuid` | NO | — | FK -> `clinics(id)` ON DELETE CASCADE |
| `doctor_id` | `uuid` | NO | — | FK -> `profiles(id)` ON DELETE CASCADE |
| `name` | `text` | NO | — | Service name (e.g. 'General Consultation') |
| `fee` | `numeric(10,2)`| NO | `0.00` | Consultation fee in PKR |
| `is_active` | `boolean`| NO | `true` | Active status |
| `created_at` | `timestamptz`| NO | `now()` | Timestamp |

### 6. `public.doctor_availability`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `doctor_id` | `uuid` | NO | — | FK -> `profiles(id)` ON DELETE CASCADE |
| `clinic_id` | `uuid` | YES | `NULL` | FK -> `clinics(id)` |
| `day_of_week` | `text` | NO | — | 'Monday', 'Tuesday', ..., 'Sunday' |
| `start_time` | `time` | NO | `'10:00:00'` | Shift start time |
| `end_time` | `time` | NO | `'16:00:00'` | Shift end time |
| `is_available` | `boolean`| NO | `true` | Availability active flag |

### 7. `public.appointments`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `reference_no` | `text` | NO | — | Formatted reference (e.g. 'SP-APT-0001') |
| `patient_id` | `uuid` | NO | — | FK -> `profiles(id)` |
| `doctor_id` | `uuid` | NO | — | FK -> `profiles(id)` |
| `clinic_id` | `uuid` | YES | `NULL` | FK -> `clinics(id)` |
| `service_id` | `uuid` | YES | `NULL` | FK -> `clinic_services(id)` |
| `service_name` | `text` | NO | `'General Consultation'`| Snapshot of service name |
| `appointment_date`| `date` | NO | — | Date of appointment |
| `appointment_time`| `text` | NO | — | Slot time (e.g. '10:00 AM') |
| `consultation_fee`| `numeric(10,2)`| NO | `0.00` | Doctor's fee snapshot |
| `platform_fee` | `numeric(10,2)`| NO | `100.00` | Platform service fee |
| `total_amount` | `numeric(10,2)`| NO | `100.00` | Total charged |
| `payment_status` | `text` | NO | `'pending'` | 'pending', 'paid', 'refunded' |
| `payment_method` | `text` | NO | `'card'` | 'card', 'wallet', 'cash' |
| `status` | `text` | NO | `'pending'` | 'pending', 'confirmed', 'completed', 'cancelled' |
| `cancellation_reason`| `text`| YES| `NULL` | Reason if cancelled |
| `created_at` | `timestamptz`| NO | `now()` | Booking created timestamp |
| `updated_at` | `timestamptz`| NO | `now()` | Status updated timestamp |

### 8. `public.patient_medicines`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `patient_id` | `uuid` | NO | — | FK -> `profiles(id)` ON DELETE CASCADE |
| `name` | `text` | NO | — | Medicine name (e.g. 'Panadol') |
| `dosage` | `text` | NO | — | e.g. '1 Tablet', '500mg' |
| `instruction` | `text` | NO | — | e.g. 'After Dinner', 'Before Breakfast' |
| `scheduled_time`| `text` | NO | — | e.g. '8:00 PM' |
| `is_active` | `boolean`| NO | `true` | Active prescription status |
| `created_at` | `timestamptz`| NO | `now()` | Timestamp |

### 9. `public.medicine_dose_logs`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `medicine_id` | `uuid` | NO | — | FK -> `patient_medicines(id)` ON DELETE CASCADE |
| `patient_id` | `uuid` | NO | — | FK -> `profiles(id)` ON DELETE CASCADE |
| `dose_date` | `date` | NO | `CURRENT_DATE` | Date of dose |
| `status` | `text` | NO | `'upcoming'` | 'taken', 'upcoming', 'missed' |
| `logged_at` | `timestamptz`| YES | `NULL` | Intake timestamp |

### 10. `public.medical_reports`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `patient_id` | `uuid` | NO | — | FK -> `profiles(id)` ON DELETE CASCADE |
| `title` | `text` | NO | — | Report title (e.g. 'CBC Report') |
| `lab_facility` | `text` | NO | — | Lab name (e.g. 'Chughtai Lab') |
| `report_date` | `date` | NO | `CURRENT_DATE` | Date of report |
| `category` | `text` | NO | `'other'` | 'bloodTest', 'scan', 'other' |
| `storage_file_path`| `text` | YES | `NULL` | Supabase Storage path in `medical-reports` |
| `file_name` | `text` | YES | `NULL` | Original file name |
| `file_size_bytes` | `bigint`| YES | `NULL` | File size |
| `mime_type` | `text` | YES | `NULL` | 'application/pdf', 'image/jpeg', etc. |
| `summary` | `text` | YES | `NULL` | Report summary |
| `created_at` | `timestamptz`| NO | `now()` | Timestamp |

### 11. `public.emergency_settings`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `patient_id` | `uuid` | NO | — | Primary Key, FK -> `profiles(id)` ON DELETE CASCADE |
| `emergency_token`| `uuid` | NO | `gen_random_uuid()`| Public scanning identifier for QR |
| `contact_name` | `text` | NO | `''` | Emergency contact full name |
| `contact_relationship`| `text`| NO | `''` | Relationship (e.g. 'Friend', 'Brother') |
| `contact_phone` | `text` | NO | `''` | Emergency contact phone number |
| `share_name` | `boolean`| NO | `true` | QR toggle: share patient name |
| `share_blood_group`| `boolean`| NO | `true` | QR toggle: share blood group |
| `share_allergies` | `boolean`| NO | `true` | QR toggle: share allergies |
| `share_medical_conditions`| `boolean`| NO | `true` | QR toggle: share medical conditions |
| `share_important_medicines`| `boolean`| NO | `true` | QR toggle: share current medicines |
| `share_emergency_contact` | `boolean`| NO | `true` | QR toggle: share emergency contact |
| `updated_at` | `timestamptz`| NO | `now()` | Last updated timestamp |

### 12. `public.doctor_consultation_notes`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `appointment_id` | `uuid` | YES | `NULL` | FK -> `appointments(id)` |
| `doctor_id` | `uuid` | NO | — | FK -> `profiles(id)` |
| `patient_id` | `uuid` | NO | — | FK -> `profiles(id)` |
| `diagnosis` | `text` | YES | `NULL` | Doctor diagnosis |
| `notes` | `text` | YES | `NULL` | Clinical observation notes |
| `prescriptions` | `jsonb` | YES | `'[]'::jsonb`| Prescribed medicines list |
| `created_at` | `timestamptz`| NO | `now()` | Timestamp |

### 13. `public.sehat_ai_chats`
| Column | Type | Nullable | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key |
| `user_id` | `uuid` | NO | — | FK -> `profiles(id)` ON DELETE CASCADE |
| `sender` | `text` | NO | `'user'` | 'user' or 'ai' |
| `message` | `text` | NO | — | Message text |
| `metadata` | `jsonb` | YES | `'{}'::jsonb` | AI tokens, suggestions, RAG references |
| `created_at` | `timestamptz`| NO | `now()` | Timestamp |

---

## F. Foreign-Key Relationships

1. `patient_profiles.patient_id` $\rightarrow$ `profiles.id` (1:1, CASCADE)
2. `doctor_profiles.doctor_id` $\rightarrow$ `profiles.id` (1:1, CASCADE)
3. `clinics.doctor_id` $\rightarrow$ `profiles.id` (1:1/1:N, CASCADE)
4. `clinic_services.clinic_id` $\rightarrow$ `clinics.id` (N:1, CASCADE)
5. `clinic_services.doctor_id` $\rightarrow$ `profiles.id` (N:1, CASCADE)
6. `doctor_availability.doctor_id` $\rightarrow$ `profiles.id` (N:1, CASCADE)
7. `doctor_availability.clinic_id` $\rightarrow$ `clinics.id` (N:1, SET NULL)
8. `appointments.patient_id` $\rightarrow$ `profiles.id` (N:1, RESTRICT)
9. `appointments.doctor_id` $\rightarrow$ `profiles.id` (N:1, RESTRICT)
10. `appointments.clinic_id` $\rightarrow$ `clinics.id` (N:1, SET NULL)
11. `appointments.service_id` $\rightarrow$ `clinic_services.id` (N:1, SET NULL)
12. `patient_medicines.patient_id` $\rightarrow$ `profiles.id` (N:1, CASCADE)
13. `medicine_dose_logs.medicine_id` $\rightarrow$ `patient_medicines.id` (N:1, CASCADE)
14. `medicine_dose_logs.patient_id` $\rightarrow$ `profiles.id` (N:1, CASCADE)
15. `medical_reports.patient_id` $\rightarrow$ `profiles.id` (N:1, CASCADE)
16. `emergency_settings.patient_id` $\rightarrow$ `profiles.id` (1:1, CASCADE)
17. `doctor_consultation_notes.appointment_id` $\rightarrow$ `appointments.id` (N:1, SET NULL)
18. `doctor_consultation_notes.doctor_id` $\rightarrow$ `profiles.id` (N:1, CASCADE)
19. `doctor_consultation_notes.patient_id` $\rightarrow$ `profiles.id` (N:1, CASCADE)
20. `sehat_ai_chats.user_id` $\rightarrow$ `profiles.id` (N:1, CASCADE)

---

## G. RLS & Security Strategy

### 1. Access Matrix

| Table | Patient Access | Doctor Access | Public / Anon Access |
|---|---|---|---|
| `profiles` | Read all profiles (doctor discovery), Update own | Read all profiles, Update own | Read-only published doctors |
| `patient_profiles` | Full CRUD on `patient_id = auth.uid()` | Read-only for patients with confirmed appointments | None |
| `doctor_profiles` | Read-only where `is_published = true` | Full CRUD on `doctor_id = auth.uid()` | Read-only published |
| `clinics` | Read-only | Full CRUD on `doctor_id = auth.uid()` | Read-only |
| `clinic_services` | Read-only | Full CRUD on `doctor_id = auth.uid()` | Read-only |
| `doctor_availability`| Read-only | Full CRUD on `doctor_id = auth.uid()` | Read-only |
| `appointments` | Select, Insert, Update own (`patient_id = auth.uid()`) | Select, Update (accept/decline/complete) where `doctor_id = auth.uid()` | None |
| `patient_medicines` | Full CRUD on `patient_id = auth.uid()` | Read-only for treating patients | None |
| `medicine_dose_logs`| Full CRUD on `patient_id = auth.uid()` | Read-only for treating patients | None |
| `medical_reports` | Full CRUD on `patient_id = auth.uid()` | Read-only for treating patients | None |
| `emergency_settings`| Full CRUD on `patient_id = auth.uid()` | Read-only if treating patient | **No direct table access** |
| `sehat_ai_chats` | Full CRUD on `user_id = auth.uid()` | None | None |

### 2. Emergency QR Safe Scans via RPC Function
To prevent exposing raw database tables or non-permitted fields to public scanners, direct table access to `emergency_settings` is denied to anonymous users. The QR code points to an endpoint executing this PostgreSQL function:

```sql
CREATE OR REPLACE FUNCTION get_public_emergency_info(p_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'full_name', CASE WHEN e.share_name THEN p.full_name ELSE NULL END,
    'blood_group', CASE WHEN e.share_blood_group THEN pp.blood_group ELSE NULL END,
    'allergies', CASE WHEN e.share_allergies THEN pp.allergies ELSE NULL END,
    'medical_conditions', CASE WHEN e.share_medical_conditions THEN pp.medical_conditions ELSE NULL END,
    'important_medicines', CASE WHEN e.share_important_medicines THEN (
      SELECT jsonb_agg(jsonb_build_object('name', m.name, 'dosage', m.dosage))
      FROM patient_medicines m WHERE m.patient_id = e.patient_id AND m.is_active = true
    ) ELSE NULL END,
    'emergency_contact', CASE WHEN e.share_emergency_contact THEN jsonb_build_object(
      'name', e.contact_name,
      'relationship', e.contact_relationship,
      'phone', e.contact_phone
    ) ELSE NULL END
  ) INTO v_result
  FROM emergency_settings e
  JOIN profiles p ON p.id = e.patient_id
  LEFT JOIN patient_profiles pp ON pp.patient_id = e.patient_id
  WHERE e.emergency_token = p_token;

  RETURN v_result;
END;
$$;
```

### 3. Supabase Storage Bucket Policies
* **`avatars` Bucket**:
  * Upload: Authenticated users to `auth.uid()/*`.
  * Read: Public read.
* **`medical-reports` Bucket**:
  * Upload: Authenticated patient to `auth.uid()/*`.
  * Read: Allowed if `auth.uid() = patient_id` OR if caller is a doctor with an active/completed appointment with that patient.

---

## H. Authentication & Role Flow

```
                     ┌────────────────────────┐
                     │     App Launched       │
                     └───────────┬────────────┘
                                 │
                                 ▼
                     ┌────────────────────────┐
                     │ Supabase Auth Session? │
                     └───────────┬────────────┘
                                 │
                 ┌───────────────┴───────────────┐
                 │ No                            │ Yes
                 ▼                               ▼
     ┌────────────────────────┐      ┌────────────────────────┐
     │   Auth / Login Flow    │      │ Query `public.profiles`│
     │  (Sign In / Sign Up)   │      │   for current user ID  │
     └───────────┬────────────┘      └───────────┬────────────┘
                 │ (Success)                     │
                 └───────────────┬───────────────┘
                                 │
                                 ▼
                     ┌────────────────────────┐
                     │  Check Profile Role    │
                     └───────────┬────────────┘
                                 │
                 ┌───────────────┴───────────────┐
                 │ role == 'patient'             │ role == 'doctor'
                 ▼                               ▼
     ┌────────────────────────┐      ┌────────────────────────┐
     │        AppShell        │      │ Check `doctor_profiles`│
     │   (Patient Dashboard)  │      │     `is_published`     │
     └────────────────────────┘      └───────────┬────────────┘
                                                 │
                                 ┌───────────────┴───────────────┐
                                 │ is_published == false         │ is_published == true
                                 ▼                               ▼
                     ┌────────────────────────┐      ┌────────────────────────┐
                     │ DoctorOnboardingScreen │      │   DoctorShellScreen    │
                     │  (5-Step Clinic Setup) │      │   (Doctor Dashboard)   │
                     └────────────────────────┘      └────────────────────────┘
```

---

## I. Flutter ↔ Supabase Integration Plan

### 1. Architectural Layers Needed in Flutter
The codebase will adopt a 3-layer architecture:

```
lib/
├── core/
│   ├── network/supabase_client.dart          # Supabase client getter
│   └── errors/app_exceptions.dart            # Standardized exception handler
├── features/
│   └── [feature_name]/
│       ├── models/                           # Updated with fromMap() / toMap()
│       ├── data/                             # Feature-specific Supabase Repository
│       │   └── [feature]_repository.dart     # Supabase queries, streams, error handling
│       └── presentation/                     # Screens & Widgets consuming Repositories
```

### 2. Model Harmonization
* **`Appointment` & `DoctorAppointmentModel`**: Unify into a single `AppointmentModel` supporting both patient and doctor perspectives.
* **`Doctor` & `DoctorProfileModel`**: Query `doctor_profiles` joined with `clinics` and `clinic_services`.
* **`ReportItem`**: Add `storageFilePath`, `fileSizeBytes`, and `mimeType` for Supabase Storage download/upload.
* **`EmergencyInfoData`**: Backed by `emergency_settings` and `patient_profiles`.

---

## J. Migration & Implementation Order

1. **Phase 1: Database & Storage Provisioning**
   * Run SQL scripts for tables, constraints, foreign keys, and indexes.
   * Add trigger to populate `patient_profiles` or `doctor_profiles` on registration.
   * Deploy `get_public_emergency_info` RPC function.
   * Enable RLS and define policies.
   * Create `avatars` and `medical-reports` storage buckets.

2. **Phase 2: Authentication & Session Management in Flutter**
   * Implement `AuthRepository` (Sign Up with role selection, Sign In, Sign Out, Password Reset).
   * Create `AuthGate` / splash dispatcher in `main.dart` routing to `AppShell`, `DoctorShellScreen`, `DoctorOnboardingScreen`, or `LoginScreen`.

3. **Phase 3: Doctor Onboarding & Clinic Management**
   * Implement `DoctorRepository` and `ClinicRepository`.
   * Wire `DoctorOnboardingScreen` to save doctor profile, clinic, services, and availability, setting `is_published = true`.
   * Connect `DoctorClinicScreen` and `DoctorProfileScreen` to real-time streams.

4. **Phase 4: Patient Features Integration**
   * **Profile & Emergency Info**: Connect `ProfileScreen` and `ManageEmergencyInfoScreen` to `patient_profiles` and `emergency_settings`.
   * **Medicines**: Connect `MedicinesScreen` to `patient_medicines` and `medicine_dose_logs`.
   * **Medical Reports**: Connect `ReportsScreen` to `medical_reports` table and implement Supabase Storage file picker upload.

5. **Phase 5: Appointment Booking Flow (Patient $\leftrightarrow$ Doctor)**
   * Connect `FindDoctorScreen` to query `doctor_profiles` joining `clinics` and `clinic_services`.
   * Connect `BookAppointmentScreen` and `PaymentScreen` to insert new records into `appointments`.
   * Connect `DoctorDashboardScreen` and `DoctorAppointmentsScreen` to query and update appointment statuses (`confirmed`, `cancelled`, `completed`).
   * Connect `MyAppointmentsScreen` for patients to view real-time status updates.

6. **Phase 6: Sehat AI & Future Extensions**
   * Connect `SehatAiScreen` to store chat messages in `sehat_ai_chats`.
   * Prepare pgvector embeddings for medical report summaries.
