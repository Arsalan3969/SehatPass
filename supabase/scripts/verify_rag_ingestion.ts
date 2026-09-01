// ==============================================================================
// SehatPass: Knowledge-Base Ingestion Verification Suite
// ==============================================================================
// 1. Total chunk count check
// 2. Non-null embedding verification
// 3. 768-dimension vector validation
// 4. All 8 clinical categories validation
// 5. Unique chunk_id uniqueness check
// 6. Source and source_url presence
// 7. match_medical_knowledge() RPC similarity search test
// 8. Self-query rank and score verification
// ==============================================================================

import { createClient } from "@supabase/supabase-js";

interface MedicalKnowledgeRecord {
  id: string;
  category: string;
  title: string;
  content: string;
  source: string;
  source_url: string;
  metadata: {
    chunk_id?: string;
    [key: string]: unknown;
  } | null;
  embedding: string | number[] | null;
}

const EXPECTED_CATEGORIES = [
  "medications",
  "common_symptoms",
  "lab_tests",
  "chronic_conditions",
  "preventive_health",
  "nutrition",
  "medication_safety",
  "when_to_seek_care"
];

export async function runVerification(): Promise<void> {
  console.log("==================================================================");
  console.log("  SehatPass: Medical Knowledge RAG Verification Suite");
  console.log("==================================================================");

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error("Missing required server environment variables: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  // 1. Fetch all records from medical_knowledge_chunks
  console.log("[Test 1/8] Querying public.medical_knowledge_chunks...");
  const { data: rows, error: fetchErr } = await supabase
    .from("medical_knowledge_chunks")
    .select("id, category, title, content, source, source_url, metadata, embedding");

  if (fetchErr) {
    throw new Error(`Database query failed: ${fetchErr.message}`);
  }

  if (!rows || rows.length === 0) {
    throw new Error("Verification FAILED: No records found in public.medical_knowledge_chunks.");
  }
  console.log(`  └─> PASS: Found ${rows.length} records in knowledge base.`);

  // 2. Check for NULL embeddings
  console.log("[Test 2/8] Checking for NULL embeddings...");
  const nullEmbeddings = (rows as MedicalKnowledgeRecord[]).filter((r: MedicalKnowledgeRecord) => r.embedding === null || r.embedding === undefined);
  if (nullEmbeddings.length > 0) {
    throw new Error(`Verification FAILED: ${nullEmbeddings.length} records have NULL embeddings.`);
  }
  console.log("  └─> PASS: 0 records with NULL embeddings.");

  // 3. Verify exactly 768 dimensions for each embedding
  console.log("[Test 3/8] Validating vector dimensions (strictly 768)...");
  for (const row of rows) {
    let parsedVector: number[];
    if (typeof row.embedding === "string") {
      try {
        parsedVector = JSON.parse(row.embedding);
      } catch {
        // Handle postgres pgvector text representation "[0.123, ...]"
        const clean = row.embedding.replace(/[\[\]]/g, "").trim();
        parsedVector = clean.split(",").map(Number);
      }
    } else if (Array.isArray(row.embedding)) {
      parsedVector = row.embedding;
    } else {
      throw new Error(`Verification FAILED: Chunk '${row.title}' has unrecognizable embedding format.`);
    }

    if (!Array.isArray(parsedVector) || parsedVector.length !== 768) {
      throw new Error(`Verification FAILED: Chunk '${row.title}' has dimension ${parsedVector?.length}, expected 768.`);
    }
  }
  console.log(`  └─> PASS: All ${rows.length} embeddings verified with exactly 768 dimensions.`);

  // 4. Verify all 8 categories exist
  console.log("[Test 4/8] Validating category coverage across 8 clinical domains...");
  const presentCategories = new Set((rows as MedicalKnowledgeRecord[]).map((r: MedicalKnowledgeRecord) => r.category));
  for (const cat of EXPECTED_CATEGORIES) {
    if (!presentCategories.has(cat)) {
      throw new Error(`Verification FAILED: Missing required category '${cat}'.`);
    }
  }
  console.log(`  └─> PASS: All 8 required categories are actively represented.`);

  // 5. Verify no duplicate chunk_id values
  console.log("[Test 5/8] Checking chunk_id uniqueness...");
  const seenChunkIds = new Set<string>();
  for (const row of rows) {
    const chunkId = row.metadata?.chunk_id;
    if (!chunkId) {
      throw new Error(`Verification FAILED: Row '${row.title}' is missing metadata.chunk_id.`);
    }
    if (seenChunkIds.has(chunkId)) {
      throw new Error(`Verification FAILED: Duplicate chunk_id detected: '${chunkId}'.`);
    }
    seenChunkIds.add(chunkId);
  }
  console.log(`  └─> PASS: All ${seenChunkIds.size} chunk_id values are strictly unique.`);

  // 6. Verify source and source_url presence
  console.log("[Test 6/8] Checking authoritative source citations...");
  for (const row of rows) {
    if (!row.source || row.source.trim() === "") {
      throw new Error(`Verification FAILED: Chunk '${row.title}' is missing 'source'.`);
    }
    if (!row.source_url || !row.source_url.startsWith("http")) {
      throw new Error(`Verification FAILED: Chunk '${row.title}' is missing a valid 'source_url'.`);
    }
  }
  console.log("  └─> PASS: All chunks contain authoritative sources and URLs.");

  // 7. Verify match_medical_knowledge() RPC execution
  console.log("[Test 7/8] Testing match_medical_knowledge() RPC similarity search...");
  const firstRow = rows[0];
  let queryEmbedding: number[];
  if (typeof firstRow.embedding === "string") {
    try {
      queryEmbedding = JSON.parse(firstRow.embedding);
    } catch {
      queryEmbedding = firstRow.embedding.replace(/[\[\]]/g, "").split(",").map(Number);
    }
  } else {
    queryEmbedding = firstRow.embedding;
  }

  const queryVectorString = `[${queryEmbedding.join(",")}]`;

  const { data: rpcMatches, error: rpcError } = await supabase.rpc("match_medical_knowledge", {
    query_embedding: queryVectorString,
    match_threshold: 0.70,
    match_count: 5
  });

  if (rpcError) {
    throw new Error(`RPC match_medical_knowledge execution failed: ${rpcError.message}`);
  }

  if (!rpcMatches || rpcMatches.length === 0) {
    throw new Error("Verification FAILED: match_medical_knowledge returned 0 matches for self-query.");
  }
  console.log(`  └─> PASS: RPC returned ${rpcMatches.length} matches (threshold >= 0.70).`);

  // 8. Verify self-query rank and score
  console.log("[Test 8/8] Verifying top similarity match accuracy...");
  const topMatch = rpcMatches[0];
  console.log(`  └─> Target: "${firstRow.title}" | Top Match: "${topMatch.title}" (Score: ${topMatch.similarity})`);
  if (topMatch.title !== firstRow.title || topMatch.similarity < 0.99) {
    throw new Error(`Verification FAILED: Expected self-match similarity ~1.0, got ${topMatch.similarity} for "${topMatch.title}".`);
  }
  console.log("  └─> PASS: Self-query verified with near-perfect cosine similarity score.");

  console.log("==================================================================");
  console.log("  ALL 8 VERIFICATION CHECKS PASSED SUCCESSFULLY!");
  console.log("==================================================================");
}

if (import.meta.main) {
  runVerification().catch((err) => {
    console.error(`[Verification Fatal Error]: ${err.message}`);
    Deno.exit(1);
  });
}
