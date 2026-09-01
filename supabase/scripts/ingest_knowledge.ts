// ==============================================================================
// SehatPass: Medical Knowledge Ingestion Script (Server/Admin Only)
// ==============================================================================
// - Model: gemini-embedding-001 (768 dimensions)
// - Server-side only: Reads GEMINI_API_KEY and SUPABASE_SERVICE_ROLE_KEY via Deno.env
// - Concurrency-safe: Database-level atomic upsert on ((metadata->>'chunk_id'))
// - Zero PII: Curated medical reference knowledge only
// ==============================================================================

import { createClient } from "@supabase/supabase-js";

interface MedicalKnowledgeSeedChunk {
  category: string;
  title: string;
  content: string;
  source: string;
  source_url: string;
  metadata: {
    chunk_id: string;
    category: string;
    source: string;
    source_url: string;
    embedding_model: string;
    embedding_dim: number;
    ingestion_version: string;
    keywords: string[];
    [key: string]: unknown;
  };
}

const REQUIRED_CATEGORIES = new Set([
  "medications",
  "common_symptoms",
  "lab_tests",
  "chronic_conditions",
  "preventive_health",
  "nutrition",
  "medication_safety",
  "when_to_seek_care"
]);

/**
 * Validates the structure and uniqueness of the seed dataset before processing.
 */
function validateSeedData(items: unknown[]): MedicalKnowledgeSeedChunk[] {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error("Validation Error: Seed dataset is empty or not an array.");
  }

  const seenChunkIds = new Set<string>();

  for (let i = 0; i < items.length; i++) {
    const item = items[i] as MedicalKnowledgeSeedChunk;
    const indexStr = `Item [index ${i}]`;

    if (!item.category || typeof item.category !== "string") {
      throw new Error(`${indexStr}: Missing or invalid 'category'.`);
    }
    if (!REQUIRED_CATEGORIES.has(item.category)) {
      throw new Error(`${indexStr}: Invalid category '${item.category}'.`);
    }
    if (!item.title || typeof item.title !== "string" || item.title.trim() === "") {
      throw new Error(`${indexStr}: Missing or invalid 'title'.`);
    }
    if (!item.content || typeof item.content !== "string" || item.content.trim() === "") {
      throw new Error(`${indexStr}: Missing or invalid 'content'.`);
    }
    if (!item.source || typeof item.source !== "string") {
      throw new Error(`${indexStr}: Missing or invalid 'source'.`);
    }
    if (!item.source_url || typeof item.source_url !== "string" || !item.source_url.startsWith("http")) {
      throw new Error(`${indexStr}: Missing or invalid 'source_url' (must be a valid URL).`);
    }
    if (!item.metadata || typeof item.metadata !== "object") {
      throw new Error(`${indexStr}: Missing or invalid 'metadata' object.`);
    }

    const chunkId = item.metadata.chunk_id;
    if (!chunkId || typeof chunkId !== "string" || chunkId.trim() === "") {
      throw new Error(`${indexStr}: Missing or invalid 'metadata.chunk_id'.`);
    }
    if (seenChunkIds.has(chunkId)) {
      throw new Error(`${indexStr}: Duplicate chunk_id detected: '${chunkId}'.`);
    }
    seenChunkIds.add(chunkId);
  }

  return items as MedicalKnowledgeSeedChunk[];
}

/**
 * Calls Gemini Embedding API using gemini-embedding-001 with 768 output dimensionality.
 * Server-side invocation only.
 */
async function generateGeminiEmbedding(text: string, apiKey: string): Promise<number[]> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${apiKey}`;

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "models/gemini-embedding-001",
      content: {
        parts: [{ text }]
      },
      outputDimensionality: 768
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini Embedding API call failed (HTTP ${response.status}): ${errorText}`);
  }

  const result = await response.json();
  const values: number[] = result.embedding?.values;

  if (!values || !Array.isArray(values)) {
    throw new Error("Gemini API returned an invalid response structure: missing embedding.values array.");
  }

  if (values.length !== 768) {
    throw new Error(`Embedding dimensionality mismatch: expected exactly 768 dimensions, received ${values.length}.`);
  }

  return values;
}

/**
 * Main server-side ingestion routine using atomic database upsert.
 */
export async function runIngestion(): Promise<{ inserted: number; updated: number; total: number }> {
  console.log("==================================================================");
  console.log("  SehatPass: Medical Knowledge Ingestion (Server-Side Admin)");
  console.log("==================================================================");

  // 1. Validate environment variables safely without leaking secret values
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!geminiApiKey) {
    throw new Error("Missing required server environment variable: GEMINI_API_KEY.");
  }
  if (!supabaseUrl) {
    throw new Error("Missing required server environment variable: SUPABASE_URL.");
  }
  if (!supabaseServiceKey) {
    throw new Error("Missing required server environment variable: SUPABASE_SERVICE_ROLE_KEY.");
  }

  // 2. Initialize Supabase Admin Client
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  // 3. Load and validate seed dataset
  const seedFileUrl = new URL("../knowledge_seed/medical_seed_data.json", import.meta.url);
  const rawSeedText = await Deno.readTextFile(seedFileUrl);
  const parsedJson = JSON.parse(rawSeedText);
  const seedChunks = validateSeedData(parsedJson);

  console.log(`[Seed Dataset] Loaded and validated ${seedChunks.length} curated medical knowledge chunks.`);

  let insertedCount = 0;
  let updatedCount = 0;

  for (let i = 0; i < seedChunks.length; i++) {
    const chunk = seedChunks[i];
    const chunkId = chunk.metadata.chunk_id;
    console.log(`[Processing ${i + 1}/${seedChunks.length}] chunk_id: '${chunkId}' | Title: "${chunk.title}"`);

    // Prepare embedding input from Title and Content
    const textToEmbed = `${chunk.title}\n\n${chunk.content}`;
    const embedding = await generateGeminiEmbedding(textToEmbed, geminiApiKey);

    // Format vector string for pgvector compatibility
    const vectorString = `[${embedding.join(",")}]`;

    // Execute atomic PostgreSQL upsert via upsert_medical_knowledge_chunk RPC
    // This executes: INSERT ... ON CONFLICT ((metadata->>'chunk_id')) DO UPDATE ...
    // Guaranteed to be completely race-condition and concurrency proof.
    const { data: upsertResult, error: upsertError } = await supabase.rpc("upsert_medical_knowledge_chunk", {
      p_category: chunk.category,
      p_title: chunk.title,
      p_content: chunk.content,
      p_source: chunk.source,
      p_source_url: chunk.source_url,
      p_metadata: chunk.metadata,
      p_embedding: vectorString
    });

    if (upsertError) {
      throw new Error(`Atomic upsert failed for chunk '${chunkId}': ${upsertError.message}`);
    }

    const isInserted = upsertResult && upsertResult[0]?.is_inserted === true;
    if (isInserted) {
      insertedCount++;
      console.log(`  └─> [INSERTED] New chunk ID '${chunkId}'.`);
    } else {
      updatedCount++;
      console.log(`  └─> [UPDATED] Existing chunk ID '${chunkId}'.`);
    }

    // Rate-limiting delay to respect Gemini API thresholds
    await new Promise((resolve) => setTimeout(resolve, 150));
  }

  console.log("==================================================================");
  console.log(`[Ingestion Complete] Total: ${seedChunks.length} | Inserted: ${insertedCount} | Updated: ${updatedCount}`);
  console.log("==================================================================");

  return { inserted: insertedCount, updated: updatedCount, total: seedChunks.length };
}

if (import.meta.main) {
  runIngestion().catch((err) => {
    console.error(`[Ingestion Fatal Error]: ${err.message}`);
    Deno.exit(1);
  });
}
