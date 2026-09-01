-- ==============================================================================
-- SehatPass Migration: Sehat AI RAG Knowledge Base Foundation (Hardened)
-- ==============================================================================
-- 1. Enable pgvector extension
-- 2. Create curated medical_knowledge_chunks table with RLS
-- 3. Create HNSW index for cosine distance similarity
-- 4. Create SECURITY INVOKER similarity search RPC function
-- ==============================================================================

-- 1. Enable pgvector extension (Supabase-supported)
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- 2. Create public.medical_knowledge_chunks for reference medical knowledge
CREATE TABLE IF NOT EXISTS public.medical_knowledge_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    source TEXT NULL,
    source_url TEXT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    embedding extensions.vector(768) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Create HNSW vector similarity index using cosine distance
CREATE INDEX IF NOT EXISTS idx_medical_knowledge_chunks_embedding
ON public.medical_knowledge_chunks
USING hnsw (embedding extensions.vector_cosine_ops);

-- Standard index for category-based filtering
CREATE INDEX IF NOT EXISTS idx_medical_knowledge_chunks_category
ON public.medical_knowledge_chunks (category);

-- 4. Create secure similarity search RPC function
-- Uses SECURITY INVOKER (caller privileges) and immutable search_path
CREATE OR REPLACE FUNCTION public.match_medical_knowledge(
    query_embedding extensions.vector(768),
    match_threshold float,
    match_count int
)
RETURNS TABLE (
    id UUID,
    category TEXT,
    title TEXT,
    content TEXT,
    source TEXT,
    source_url TEXT,
    metadata JSONB,
    similarity float
)
LANGUAGE plpgsql
STABLE
PARALLEL SAFE
SECURITY INVOKER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
    RETURN QUERY
    SELECT
        mkc.id,
        mkc.category,
        mkc.title,
        mkc.content,
        mkc.source,
        mkc.source_url,
        mkc.metadata,
        (1 - (mkc.embedding <=> query_embedding))::float AS similarity
    FROM public.medical_knowledge_chunks mkc
    WHERE mkc.embedding IS NOT NULL
      AND (1 - (mkc.embedding <=> query_embedding)) >= match_threshold
    ORDER BY mkc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 5. Row Level Security (RLS) & Access Control
ALTER TABLE public.medical_knowledge_chunks ENABLE ROW LEVEL SECURITY;

-- Revoke all default public/anon permissions
REVOKE ALL ON public.medical_knowledge_chunks FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.match_medical_knowledge(extensions.vector(768), float, int) FROM PUBLIC, anon;

-- Allow authenticated read-only access to curated knowledge
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'medical_knowledge_chunks'
          AND policyname = 'Allow authenticated read-only access to medical knowledge'
    ) THEN
        CREATE POLICY "Allow authenticated read-only access to medical knowledge"
        ON public.medical_knowledge_chunks
        FOR SELECT
        TO authenticated
        USING (true);
    END IF;
END $$;

-- Grant minimal necessary table privileges
GRANT SELECT ON public.medical_knowledge_chunks TO authenticated;
GRANT ALL ON public.medical_knowledge_chunks TO service_role;

-- Grant RPC execute permissions
GRANT EXECUTE ON FUNCTION public.match_medical_knowledge(extensions.vector(768), float, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_medical_knowledge(extensions.vector(768), float, int) TO service_role;
