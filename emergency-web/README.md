# SehatPass Public Emergency Web App

This directory contains the standalone, lightweight, mobile-first **SehatPass Emergency Medical Profile Web App**.

---

## 🏗️ Architecture

```
Patient Emergency QR (Scanned by Phone)
           ↓
   Public Emergency Web App (Vercel / Netlify / Custom Domain)
   https://emergency.sehatpass.app/?token=<random-uuid>
           ↓
   Supabase Edge Function (JSON API)
   https://vnavceiizdjekbmtzpsn.supabase.co/functions/v1/emergency-access?token=<random-uuid>&format=json
           ↓
   PostgreSQL `get_public_emergency_info` RPC (Secure Emergency Data Only)
```

---

## 🚀 Local Testing

You can run this web app locally using Python or Node:

### Option 1: Python HTTP Server
```bash
cd emergency-web
python -m http.server 3000
```
Then open:
- `http://localhost:3000/?token=00000000-0000-4000-8000-000000000000` (Simulates inactive/revoked token)
- `http://localhost:3000/?token=invalid-token` (Simulates invalid token)
- `http://localhost:3000/` (Simulates missing token)

### Option 2: Node.js (npx serve)
```bash
npx serve emergency-web -p 3000
```

---

## 🌐 Production Deployment Steps

### Option A: Deploy to Vercel (Recommended)
1. Install Vercel CLI (if not installed):
   ```bash
   npm install -g vercel
   ```
2. Log in to Vercel:
   ```bash
   vercel login
   ```
3. Deploy the `emergency-web` folder:
   ```bash
   cd emergency-web
   vercel --prod
   ```
4. Copy your production URL (e.g. `https://sehatpass-emergency.vercel.app`).
5. Add it to your `.env` in the root SehatPass Flutter project:
   ```env
   EMERGENCY_WEB_URL=https://sehatpass-emergency.vercel.app
   ```

### Option B: Deploy to Netlify
1. Install Netlify CLI:
   ```bash
   npm install -g netlify-cli
   ```
2. Log in to Netlify:
   ```bash
   netlify login
   ```
3. Deploy the folder:
   ```bash
   cd emergency-web
   netlify deploy --prod --dir=.
   ```
4. Copy your production URL (e.g. `https://sehatpass-emergency.netlify.app`).
5. Add it to your `.env` in the root SehatPass Flutter project:
   ```env
   EMERGENCY_WEB_URL=https://sehatpass-emergency.netlify.app
   ```

---

## 🔒 Security Summary
* Zero credentials, Supabase service-role keys, or secret tokens stored in this web app.
* Strict XSS prevention: DOM elements populated safely via `textContent` and `createElement`.
* No patient data logged to browser console or persisted in `localStorage`.
