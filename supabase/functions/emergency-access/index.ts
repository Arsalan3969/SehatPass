// ==============================================================================
// SehatPass: Emergency Medical Access Edge Function
// ==============================================================================
// 1. Validates opaque emergency token (UUID v4)
// 2. Invokes get_public_emergency_info RPC to retrieve emergency-permitted fields only
// 3. Renders a modern, responsive, mobile-first HTML Emergency Medical Profile page
//    or JSON response for programmatic API inspection
// 4. Zero auth required for first responders (instant browser access on QR scan)
// 5. Zero sensitive credentials (passwords, JWTs, keys, consults, logs) exposed
// ==============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

interface EmergencyMedication {
  name: string;
  dosage?: string;
  instruction?: string;
  scheduled_time?: string;
}

interface EmergencyContact {
  name?: string | null;
  relationship?: string | null;
  phone?: string | null;
}

interface EmergencyMedicalReport {
  id: string;
  title: string;
  lab_facility?: string | null;
  report_date?: string | null;
  category?: string | null;
  file_name?: string | null;
  file_size_bytes?: number | null;
  mime_type?: string | null;
  view_url?: string | null;
}

interface RawMedicalReport {
  id: string;
  title: string;
  lab_facility?: string | null;
  report_date?: string | null;
  category?: string | null;
  storage_file_path?: string | null;
  file_name?: string | null;
  file_size_bytes?: number | null;
  mime_type?: string | null;
}

interface EmergencyData {
  is_active?: boolean;
  full_name?: string | null;
  date_of_birth?: string | null;
  gender?: string | null;
  blood_group?: string | null;
  allergies?: string | null;
  medical_conditions?: string | null;
  important_medicines?: EmergencyMedication[];
  emergency_contact?: EmergencyContact | null;
  medical_reports?: EmergencyMedicalReport[];
  updated_at?: string;
}

function escapeHtml(text: string | null | undefined): string {
  if (!text) return "";
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function getCommonStyles(): string {
  return `
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: #0B1120;
      color: #1E293B;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: flex-start;
      padding: 16px 12px 32px;
      -webkit-font-smoothing: antialiased;
    }
    .wrapper {
      width: 100%;
      max-width: 480px;
      background: #FFFFFF;
      border-radius: 20px;
      overflow: hidden;
      box-shadow: 0 20px 35px -10px rgba(0, 0, 0, 0.4), 0 0 1px 1px rgba(255, 255, 255, 0.1);
    }
    .header-banner {
      background: linear-gradient(135deg, #DC2626 0%, #991B1B 100%);
      color: #FFFFFF;
      padding: 24px 20px;
      text-align: center;
      position: relative;
    }
    .header-tag {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(255, 255, 255, 0.2);
      border: 1px solid rgba(255, 255, 255, 0.3);
      padding: 4px 12px;
      border-radius: 9999px;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.05em;
      text-transform: uppercase;
      margin-bottom: 8px;
    }
    .header-title {
      font-size: 22px;
      font-weight: 800;
      letter-spacing: -0.02em;
      line-height: 1.2;
    }
    .header-subtitle {
      font-size: 12px;
      font-weight: 500;
      opacity: 0.9;
      margin-top: 4px;
      letter-spacing: 0.02em;
      text-transform: uppercase;
    }
    .content {
      padding: 18px 16px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .card-section {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 14px;
      padding: 14px 16px;
    }
    .section-header {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 11px;
      font-weight: 700;
      color: #64748B;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 10px;
      border-bottom: 1px solid #EEF2F6;
      padding-bottom: 6px;
    }
    .hero-identity {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 12px;
    }
    .patient-name {
      font-size: 20px;
      font-weight: 800;
      color: #0F172A;
      line-height: 1.2;
    }
    .patient-meta {
      font-size: 13px;
      color: #475569;
      margin-top: 4px;
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: center;
    }
    .meta-dot {
      color: #CBD5E1;
    }
    .blood-badge-container {
      flex-shrink: 0;
      text-align: center;
    }
    .blood-badge {
      display: inline-flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: #FEE2E2;
      border: 2px solid #F87171;
      color: #991B1B;
      border-radius: 12px;
      min-width: 60px;
      padding: 6px 10px;
    }
    .blood-group-val {
      font-size: 20px;
      font-weight: 900;
      line-height: 1;
    }
    .blood-group-lbl {
      font-size: 9px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-top: 2px;
      opacity: 0.8;
    }
    .alert-card {
      border-radius: 10px;
      padding: 10px 12px;
      margin-bottom: 8px;
    }
    .alert-card:last-child {
      margin-bottom: 0;
    }
    .alert-card.allergy {
      background: #FEF2F2;
      border: 1px solid #FECACA;
    }
    .alert-card.condition {
      background: #FFFBEB;
      border: 1px solid #FDE68A;
    }
    .alert-label {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      margin-bottom: 3px;
    }
    .alert-card.allergy .alert-label { color: #B91C1C; }
    .alert-card.condition .alert-label { color: #B45309; }
    .alert-value {
      font-size: 14px;
      font-weight: 600;
      line-height: 1.4;
    }
    .alert-card.allergy .alert-value { color: #7F1D1D; }
    .alert-card.condition .alert-value { color: #78350F; }

    .contact-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      background: #EFF6FF;
      border: 1px solid #BFDBFE;
      border-radius: 12px;
      padding: 12px;
    }
    .contact-name {
      font-size: 15px;
      font-weight: 700;
      color: #1E3A8A;
    }
    .contact-rel {
      font-size: 12px;
      color: #3B82F6;
      font-weight: 600;
      margin-top: 2px;
    }
    .btn-call {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: #2563EB;
      color: #FFFFFF;
      text-decoration: none;
      font-size: 13px;
      font-weight: 700;
      padding: 8px 14px;
      border-radius: 10px;
      flex-shrink: 0;
      box-shadow: 0 2px 4px rgba(37, 99, 235, 0.2);
    }
    .btn-call:active {
      transform: scale(0.97);
    }

    .med-item {
      background: #FFFFFF;
      border: 1px solid #E2E8F0;
      border-radius: 8px;
      padding: 10px 12px;
      margin-bottom: 8px;
    }
    .med-item:last-child {
      margin-bottom: 0;
    }
    .med-title {
      font-size: 14px;
      font-weight: 700;
      color: #0F172A;
    }
    .med-sub {
      font-size: 12px;
      color: #64748B;
      margin-top: 2px;
    }
    .empty-state-text {
      font-size: 13px;
      color: #64748B;
      font-style: italic;
    }

    .notice-box {
      margin: 4px 16px 16px;
      background: #F1F5F9;
      border-radius: 10px;
      padding: 10px 12px;
      font-size: 11px;
      line-height: 1.45;
      color: #64748B;
      text-align: center;
    }
    .notice-box strong {
      color: #334155;
    }
    .footer-brand {
      text-align: center;
      font-size: 11px;
      color: #94A3B8;
      padding-bottom: 16px;
      font-weight: 600;
      letter-spacing: 0.04em;
    }

    /* Error / Warning States */
    .error-card-body {
      padding: 32px 20px;
      text-align: center;
    }
    .error-icon-box {
      width: 64px;
      height: 64px;
      border-radius: 50%;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 28px;
      margin-bottom: 16px;
    }
    .error-icon-box.red {
      background: #FEE2E2;
      color: #DC2626;
      border: 1px solid #FECACA;
    }
    .error-icon-box.amber {
      background: #FEF3C7;
      color: #D97706;
      border: 1px solid #FDE68A;
    }
    .error-icon-box.gray {
      background: #F1F5F9;
      color: #64748B;
      border: 1px solid #CBD5E1;
    }
    .error-heading {
      font-size: 18px;
      font-weight: 800;
      color: #0F172A;
      margin-bottom: 8px;
    }
    .error-desc {
      font-size: 13px;
      color: #64748B;
      line-height: 1.5;
      margin-bottom: 20px;
    }
    .helpline-card {
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 12px;
      padding: 12px;
      font-size: 12px;
      color: #334155;
      margin-top: 12px;
      text-align: left;
    }
    .helpline-card strong {
      display: block;
      color: #0F172A;
      margin-bottom: 4px;
      font-size: 12px;
    }
  `;
}

function renderHtmlProfile(data: EmergencyData): string {
  const name = escapeHtml(data.full_name) || "Patient Name Hidden";
  const dob = escapeHtml(data.date_of_birth) || "";
  const gender = escapeHtml(data.gender) || "";
  const bloodGroup = escapeHtml(data.blood_group) || "N/A";
  const allergies = escapeHtml(data.allergies) || "None reported";
  const conditions = escapeHtml(data.medical_conditions) || "None reported";

  const contactName = escapeHtml(data.emergency_contact?.name) || "Not listed";
  const contactRel = escapeHtml(data.emergency_contact?.relationship) || "Emergency Contact";
  const contactPhone = escapeHtml(data.emergency_contact?.phone) || "";

  const medicines = data.important_medicines || [];
  const reports = data.medical_reports || [];

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Emergency Profile - ${name} | SehatPass</title>
  <style>${getCommonStyles()}</style>
</head>
<body>
  <main class="wrapper">
    <header class="header-banner">
      <div class="header-tag">🚨 Emergency Medical Access</div>
      <h1 class="header-title">SEHATPASS</h1>
      <div class="header-subtitle">Emergency Medical Profile</div>
    </header>

    <div class="content">
      <!-- 1. Patient Identity & Blood Group -->
      <section class="card-section">
        <div class="section-header">👤 Patient Identification</div>
        <div class="hero-identity">
          <div>
            <h2 class="patient-name">${name}</h2>
            <div class="patient-meta">
              ${gender ? `<span>${gender}</span>` : ""}
              ${gender && dob ? `<span class="meta-dot">•</span>` : ""}
              ${dob ? `<span>DOB: ${dob}</span>` : ""}
              ${!gender && !dob ? `<span class="empty-state-text">Demographics not specified</span>` : ""}
            </div>
          </div>
          <div class="blood-badge-container">
            <div class="blood-badge">
              <span class="blood-group-val">${bloodGroup}</span>
              <span class="blood-group-lbl">Blood</span>
            </div>
          </div>
        </div>
      </section>

      <!-- 2. Emergency Contact -->
      <section class="card-section">
        <div class="section-header">📞 Emergency Contact</div>
        ${contactPhone ? `
        <div class="contact-row">
          <div>
            <div class="contact-name">${contactName}</div>
            <div class="contact-rel">${contactRel} • ${contactPhone}</div>
          </div>
          <a href="tel:${contactPhone}" class="btn-call" aria-label="Call Emergency Contact">
            <span>📞</span> Call
          </a>
        </div>
        ` : `
        <div style="padding: 4px 0;">
          <div class="patient-name" style="font-size: 15px;">${contactName}</div>
          <div class="patient-meta">${contactRel} • <span class="empty-state-text">No phone number recorded</span></div>
        </div>
        `}
      </section>

      <!-- 3. Critical Medical Alerts & Allergies -->
      <section class="card-section">
        <div class="section-header">⚠️ Medical Alerts &amp; Conditions</div>
        <div class="alert-card allergy">
          <div class="alert-label">Known Allergies</div>
          <div class="alert-value">${allergies}</div>
        </div>
        <div class="alert-card condition">
          <div class="alert-label">Medical Conditions / Chronic Illnesses</div>
          <div class="alert-value">${conditions}</div>
        </div>
      </section>

      <!-- 4. Important Medications -->
      <section class="card-section">
        <div class="section-header">💊 Current Medications</div>
        ${medicines.length > 0 ? medicines.map(m => `
          <div class="med-item">
            <div class="med-title">${escapeHtml(m.name)} ${m.dosage ? `(${escapeHtml(m.dosage)})` : ""}</div>
            <div class="med-sub">${escapeHtml(m.instruction || "As directed")} ${m.scheduled_time ? `• ${escapeHtml(m.scheduled_time)}` : ""}</div>
          </div>
        `).join("") : `
          <div class="empty-state-text">No active medications registered for emergency display.</div>
        `}
      </section>

      <!-- 5. Medical Reports -->
      <section class="card-section">
        <div class="section-header">📄 Medical Reports</div>
        ${reports.length > 0 ? reports.map(r => `
          <div class="med-item" style="display: flex; justify-content: space-between; align-items: center; gap: 12px;">
            <div style="flex: 1; min-width: 0;">
              <div class="med-title">${escapeHtml(r.title)}</div>
              <div class="med-sub">
                ${escapeHtml(r.lab_facility || "Laboratory")}${r.report_date ? ` • ${escapeHtml(r.report_date)}` : ""}
              </div>
            </div>
            ${r.view_url ? `
              <a href="${escapeHtml(r.view_url)}" target="_blank" rel="noopener noreferrer" class="btn-call" style="background: #2E7D5E; font-size: 12px; padding: 6px 12px; text-decoration: none;">
                View
              </a>
            ` : `
              <span style="font-size: 11px; color: #94A3B8;">Unavailable</span>
            `}
          </div>
        `).join("") : `
          <div class="empty-state-text">No medical reports available.</div>
        `}
      </section>
    </div>

    <!-- Security & Medical Disclaimer -->
    <div class="notice-box">
      <strong>🔒 Privacy &amp; Verification Notice:</strong> This profile is securely authorized by the patient through SehatPass via a unique emergency QR token. In a life-threatening crisis, immediately summon local emergency services (Rescue 1122 / 911).
    </div>

    <div class="footer-brand">
      SEHATPASS EMERGENCY CARE NETWORK
    </div>
  </main>
</body>
</html>`;
}

function renderErrorPage(
  type: "invalid_token" | "inactive_token" | "server_error",
  customMessage?: string
): string {
  let icon = "🚨";
  let iconClass = "red";
  let title = "Emergency Access Unavailable";
  let desc = customMessage || "This emergency QR code is invalid or has expired.";

  if (type === "invalid_token") {
    icon = "⚠️";
    iconClass = "amber";
    title = "Invalid Emergency Token";
    desc = "The scanned QR token is unrecognized, malformed, or missing. Please scan an authentic SehatPass Emergency QR code.";
  } else if (type === "inactive_token") {
    icon = "🔒";
    iconClass = "red";
    title = "Emergency Access Revoked";
    desc = "This emergency profile has been deactivated, revoked, or regenerated by the patient. The medical details for this QR token are no longer accessible.";
  } else if (type === "server_error") {
    icon = "⚙️";
    iconClass = "gray";
    title = "Temporary Service Notice";
    desc = "The emergency profile service is temporarily unavailable. Please refresh or verify with emergency medical personnel.";
  }

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${title} | SehatPass</title>
  <style>${getCommonStyles()}</style>
</head>
<body>
  <main class="wrapper">
    <header class="header-banner" style="background: linear-gradient(135deg, #475569 0%, #1E293B 100%);">
      <div class="header-tag">🚨 SehatPass Emergency Response</div>
      <h1 class="header-title">SEHATPASS</h1>
      <div class="header-subtitle">Emergency Verification System</div>
    </header>

    <div class="error-card-body">
      <div class="error-icon-box ${iconClass}">${icon}</div>
      <h2 class="error-heading">${title}</h2>
      <p class="error-desc">${desc}</p>

      <div class="helpline-card">
        <strong>First Responder Guidance:</strong>
        If the individual requires urgent medical attention, do not rely on digital records alone. Immediately contact local emergency medical services or transport to the nearest emergency room.
      </div>
    </div>

    <div class="notice-box">
      <strong>Security Notice:</strong> Emergency access is protected by single-purpose cryptographically unique tokens.
    </div>

    <div class="footer-brand">
      SEHATPASS SECURE HEALTHCARE PLATFORM
    </div>
  </main>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token") || "";

  const acceptHeader = req.headers.get("Accept") || "";
  const wantsJson =
    url.searchParams.get("format") === "json" ||
    (acceptHeader.startsWith("application/json") && !acceptHeader.includes("text/html"));

  const corsHeaders: Record<string, string> = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
  };

  const htmlHeaders: Record<string, string> = {
    ...corsHeaders,
    "Content-Type": "text/html; charset=utf-8",
  };

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Validate token UUID format (RFC 4122)
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!token || !uuidRegex.test(token.trim())) {
    if (wantsJson) {
      return new Response(JSON.stringify({ error: "Invalid or missing emergency token." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    return new Response(renderErrorPage("invalid_token"), {
      status: 200,
      headers: htmlHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY") ??
      "";

    if (!supabaseUrl || !supabaseKey) {
      console.error("[emergency-access] Missing SUPABASE_URL or SUPABASE_ANON_KEY");
      if (wantsJson) {
        return new Response(JSON.stringify({ error: "Server configuration error" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      return new Response(renderErrorPage("server_error"), {
        status: 200,
        headers: htmlHeaders,
      });
    }

    const client = createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data, error } = await client.rpc("get_public_emergency_info", {
      p_token: token.trim(),
    });

    if (error) {
      console.error("[emergency-access] Database RPC error:", error.message);
      if (wantsJson) {
        return new Response(JSON.stringify({ error: "Error retrieving emergency profile." }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      return new Response(renderErrorPage("server_error"), {
        status: 200,
        headers: htmlHeaders,
      });
    }

    if (!data || (data as Record<string, unknown>).is_active === false) {
      if (wantsJson) {
        return new Response(JSON.stringify({ error: "Emergency profile not found or inactive." }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      return new Response(renderErrorPage("inactive_token"), {
        status: 200,
        headers: htmlHeaders,
      });
    }

    const rawReports = Array.isArray((data as Record<string, unknown>).medical_reports)
      ? ((data as Record<string, unknown>).medical_reports as RawMedicalReport[])
      : [];

    const sanitizedReports: EmergencyMedicalReport[] = [];

    for (const rep of rawReports) {
      let viewUrl: string | null = null;
      const storagePath = rep.storage_file_path?.trim();

      if (storagePath) {
        try {
          const { data: signData, error: signError } = await client.storage
            .from("medical-reports")
            .createSignedUrl(storagePath, 600); // 600 seconds = 10 minutes

          if (!signError && signData?.signedUrl) {
            viewUrl = signData.signedUrl;
          } else if (signError) {
            console.warn(`[emergency-access] Failed to sign URL for report ${rep.id}:`, signError.message);
          }
        } catch (signEx) {
          console.warn(`[emergency-access] Error creating signed URL for report ${rep.id}:`, (signEx as Error).message);
        }
      }

      sanitizedReports.push({
        id: rep.id,
        title: rep.title || "Medical Report",
        lab_facility: rep.lab_facility || null,
        report_date: rep.report_date || null,
        category: rep.category || "other",
        file_name: rep.file_name || null,
        file_size_bytes: rep.file_size_bytes || null,
        mime_type: rep.mime_type || null,
        view_url: viewUrl,
      });
    }

    const emergencyData: EmergencyData = {
      ...(data as Record<string, unknown>),
      medical_reports: sanitizedReports,
    };

    if (wantsJson) {
      return new Response(JSON.stringify({ data: emergencyData }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(renderHtmlProfile(emergencyData), {
      status: 200,
      headers: htmlHeaders,
    });
  } catch (err) {
    console.error("[emergency-access] Unhandled error:", (err as Error).message);
    if (wantsJson) {
      return new Response(JSON.stringify({ error: "Internal server error." }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    return new Response(renderErrorPage("server_error"), {
      status: 200,
      headers: htmlHeaders,
    });
  }
});
