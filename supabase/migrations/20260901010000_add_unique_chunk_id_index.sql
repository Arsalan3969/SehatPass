-- ==============================================================================
-- SehatPass Migration: Unique Index & Atomic Upsert for Idempotent RAG Chunks
-- ==============================================================================
-- 1. Create a unique expression index on ((metadata->>'chunk_id'))
-- 2. Create atomic SECURITY DEFINER upsert RPC function for service_role
-- ==============================================================================

-- 1. Unique index on chunk_id expression
CREATE UNIQUE INDEX IF NOT EXISTS idx_medical_knowledge_chunks_chunk_id
ON public.medical_knowledge_chunks ((metadata->>'chunk_id'));

-- 2. Atomic upsert function to eliminate SELECT-then-INSERT race conditions
CREATE OR REPLACE FUNCTION public.upsert_medical_knowledge_chunk(
    p_category TEXT,
    p_title TEXT,
    p_content TEXT,
    p_source TEXT,
    p_source_url TEXT,
    p_metadata JSONB,
    p_embedding extensions.vector(768)
)
RETURNS TABLE (
    id UUID,
    is_inserted BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_id UUID;
    v_inserted BOOLEAN;
BEGIN
    INSERT INTO public.medical_knowledge_chunks (
        category,
        title,
        content,
        source,
        source_url,
        metadata,
        embedding,
        updated_at
    )
    VALUES (
        p_category,
        p_title,
        p_content,
        p_source,
        p_source_url,
        p_metadata,
        p_embedding,
        now()
    )
    ON CONFLICT ((metadata->>'chunk_id'))
    DO UPDATE SET
        category = EXCLUDED.category,
        title = EXCLUDED.title,
        content = EXCLUDED.content,
        source = EXCLUDED.source,
        source_url = EXCLUDED.source_url,
        metadata = EXCLUDED.metadata,
        embedding = EXCLUDED.embedding,
        updated_at = now()
    RETURNING medical_knowledge_chunks.id, (xmax = 0) INTO v_id, v_inserted;

    RETURN QUERY SELECT v_id, v_inserted;
END;
$$;

-- 3. Restrict access: Admin/Service role only
REVOKE ALL ON FUNCTION public.upsert_medical_knowledge_chunk(TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, extensions.vector(768)) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_medical_knowledge_chunk(TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, extensions.vector(768)) TO service_role;
