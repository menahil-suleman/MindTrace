"""
RAG Engine — Hybrid Search (Semantic + Keyword)

LEARN — The full pipeline:
───────────────────────────

INDEXING (happens once at startup):
   1. Load all clinical documents from knowledge_base.py
   2. Convert each document to a vector using the embedding model
      "I feel anxious" → [0.23, -0.81, 0.44, ...] (384 numbers)
   3. Store vectors in pgvector (Postgres)
   4. Also build a BM25 index for keyword search

RETRIEVAL (happens on every user message):
   1. Convert user message to a vector
   2. Run semantic search: find top-K most similar vectors (cosine similarity)
   3. Run keyword search: BM25 score against all documents
   4. Merge both ranked lists using RRF (Reciprocal Rank Fusion)
   5. Return top-N documents

LEARN — Why two separate search methods?

   SEMANTIC (vector) search:
   - "I can't stop worrying" → finds GAD-7 Q2 even though words don't match
   - Understands meaning, synonyms, context
   - Weakness: can miss exact clinical terms

   KEYWORD (BM25) search:
   - "GAD-7 question 3" → finds it by exact word match
   - Fast, no ML, perfectly reliable for exact terms
   - Weakness: "nervous" won't find "anxious"

   HYBRID: both run in parallel, results merged by RRF
   Gets the best of both worlds.

LEARN — Reciprocal Rank Fusion (RRF):
   For each document, score = 1/(rank_semantic + 60) + 1/(rank_keyword + 60)
   The 60 is a smoothing constant preventing top results from dominating.
   Documents appearing high in BOTH lists score highest.
   Documents in only one list still get partial credit.
"""

import asyncio
import logging
from functools import lru_cache

import numpy as np
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.rag.knowledge_base import ALL_CHUNKS, KnowledgeChunk

logger = logging.getLogger(__name__)

# ── Embedding model ───────────────────────────────────────────────────────────
# LEARN: SentenceTransformer loads the model weights from HuggingFace.
# First run: downloads ~90MB to ~/.cache/huggingface/
# Subsequent runs: loads from cache instantly.
# all-MiniLM-L6-v2: 384 dimensions, fast, good quality for semantic similarity
# We use @lru_cache so the model loads once and stays in memory.

@lru_cache(maxsize=1)
def get_embedding_model() -> SentenceTransformer:
    """
    LEARN: lru_cache means this function runs once.
    The model loads on first call, then the same object is returned every time.
    Loading a SentenceTransformer takes ~1-2 seconds — we don't want that
    on every request.
    """
    logger.info("Loading embedding model all-MiniLM-L6-v2...")
    return SentenceTransformer("all-MiniLM-L6-v2")


def embed(text: str) -> list[float]:
    """
    LEARN: Convert a string into a vector of 384 floats.
    This is the core operation of semantic search.
    The model maps the meaning of the text into a point in 384-dimensional space.
    Texts with similar meaning land close together in that space.
    """
    model = get_embedding_model()
    # encode() returns a numpy array — we convert to plain Python list
    # because that's what pgvector and JSON serialization expect
    vector = model.encode(text, normalize_embeddings=True)
    return vector.tolist()


# ── BM25 index (keyword search) ───────────────────────────────────────────────
# LEARN: BM25 (Best Match 25) is the standard keyword ranking algorithm.
# It's what Elasticsearch uses under the hood.
# It counts word frequencies but penalizes very common words (like "the", "is")
# and rewards rare, specific words.
#
# We build this in-memory because our knowledge base is small (< 100 chunks).
# For a larger knowledge base you'd use Postgres full-text search instead.

class _BM25Index:
    """
    In-memory BM25 index over our clinical knowledge base.
    Built once at startup, used for every query.
    """
    def __init__(self, chunks: list[KnowledgeChunk]) -> None:
        self.chunks = chunks
        # BM25 needs tokenized documents
        # Simple whitespace tokenization — good enough for clinical text
        tokenized = [chunk.content.lower().split() for chunk in chunks]
        self.bm25 = BM25Okapi(tokenized)

    def search(self, query: str, top_k: int = 10) -> list[tuple[int, float]]:
        """
        Returns list of (chunk_index, bm25_score) sorted by score descending.
        top_k controls how many results we consider before RRF merging.
        """
        tokens = query.lower().split()
        scores = self.bm25.get_scores(tokens)
        # argsort gives indices in ascending order — we reverse for descending
        ranked_indices = np.argsort(scores)[::-1][:top_k]
        return [(int(idx), float(scores[idx])) for idx in ranked_indices]


@lru_cache(maxsize=1)
def get_bm25_index() -> _BM25Index:
    """Single BM25 index instance over ALL_CHUNKS."""
    return _BM25Index(ALL_CHUNKS)


# ── Reciprocal Rank Fusion ────────────────────────────────────────────────────
# LEARN: RRF merges two ranked lists into one.
# Formula: score(doc) = 1/(rank_in_list1 + k) + 1/(rank_in_list2 + k)
# k=60 is the standard constant from the original RRF paper.
# A doc ranked 1st in both lists gets 1/61 + 1/61 = 0.0328
# A doc ranked 10th in both gets 1/70 + 1/70 = 0.0286
# A doc only in one list gets 1/61 + 0 = 0.0164

def _rrf_merge(
    semantic_results: list[tuple[int, float]],   # (chunk_index, similarity_score)
    keyword_results: list[tuple[int, float]],    # (chunk_index, bm25_score)
    k: int = 60,
    top_n: int = 4,
) -> list[int]:
    """
    Merge semantic and keyword ranked lists using RRF.
    Returns top_n chunk indices, best first.
    """
    scores: dict[int, float] = {}

    # Add semantic rankings
    for rank, (idx, _score) in enumerate(semantic_results):
        scores[idx] = scores.get(idx, 0.0) + 1.0 / (rank + k)

    # Add keyword rankings
    for rank, (idx, _score) in enumerate(keyword_results):
        scores[idx] = scores.get(idx, 0.0) + 1.0 / (rank + k)

    # Sort by combined RRF score, highest first
    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [idx for idx, _ in ranked[:top_n]]


# ── Database operations ───────────────────────────────────────────────────────
# LEARN: We store embeddings in Postgres using pgvector.
# The table has:
#   - content: the text chunk
#   - category: 'gad7', 'phq9', 'dass', 'dsm5'
#   - metadata: JSONB with question numbers, scores etc
#   - embedding: vector(384) — the 384-dimensional float array
#
# We use raw SQL here (not SQLAlchemy ORM models) because pgvector's
# vector type needs special handling that's simpler with raw SQL.

async def ensure_rag_schema(db: AsyncSession) -> None:
    """
    LEARN: This runs once at startup.
    It creates the pgvector extension and knowledge_chunks table if they
    don't already exist. Safe to run multiple times (IF NOT EXISTS).

    The <-> operator in pgvector means cosine distance.
    Lower distance = more similar. We convert to similarity = 1 - distance.
    """
    await db.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))

    await db.execute(text("""
        CREATE TABLE IF NOT EXISTS knowledge_chunks (
            id          SERIAL PRIMARY KEY,
            content     TEXT        NOT NULL,
            category    TEXT        NOT NULL,
            metadata    JSONB       NOT NULL DEFAULT '{}',
            -- vector(384) matches all-MiniLM-L6-v2 output dimensions
            embedding   vector(384) NOT NULL
        )
    """))

    # LEARN: IVFFlat index — divides vectors into clusters (lists) for faster search.
    # Without an index, every query scans ALL rows (slow at scale).
    # lists=10: creates 10 clusters. Rule of thumb: sqrt(num_rows).
    # vector_cosine_ops: use cosine distance metric.
    await db.execute(text("""
        CREATE INDEX IF NOT EXISTS knowledge_chunks_embedding_idx
        ON knowledge_chunks
        USING ivfflat (embedding vector_cosine_ops)
        WITH (lists = 10)
    """))

    await db.commit()
    logger.info("RAG schema ready.")


async def is_knowledge_base_seeded(db: AsyncSession) -> bool:
    """Check if knowledge base already has data — avoids re-seeding on restart."""
    result = await db.execute(text("SELECT COUNT(*) FROM knowledge_chunks"))
    count = result.scalar()
    return (count or 0) > 0


async def seed_knowledge_base(db: AsyncSession) -> None:
    """
    LEARN: This is the INDEXING phase.
    For each document in our knowledge base:
      1. Convert content to embedding vector
      2. Insert into Postgres with the vector

    We do this once. After seeding, retrieval can happen instantly.
    The embedding model runs locally — no API calls, no cost.
    """
    if await is_knowledge_base_seeded(db):
        logger.info("Knowledge base already seeded — skipping.")
        return

    logger.info(f"Seeding {len(ALL_CHUNKS)} knowledge chunks...")

    for chunk in ALL_CHUNKS:
        vector = embed(chunk.content)
        # pgvector expects the vector as a Python list
        # We cast it to string format '[0.1, 0.2, ...]' for the SQL param
        await db.execute(
            text("""
                INSERT INTO knowledge_chunks (content, category, metadata, embedding)
                VALUES (:content, :category, :metadata, :embedding::vector)
            """),
            {
                "content": chunk.content,
                "category": chunk.category,
                "metadata": str(chunk.metadata).replace("'", '"'),
                "embedding": str(vector),
            },
        )

    await db.commit()
    logger.info("Knowledge base seeded successfully.")


async def semantic_search(
    db: AsyncSession,
    query_vector: list[float],
    top_k: int = 10,
) -> list[tuple[int, float]]:
    """
    LEARN: Vector similarity search using pgvector.
    The <-> operator computes cosine distance between the query vector
    and every stored embedding.
    Lower distance = more similar.
    We ORDER BY distance ASC to get most similar first.
    Returns list of (row_id, similarity_score).
    """
    result = await db.execute(
        text("""
            SELECT id, 1 - (embedding <-> :query_vec::vector) AS similarity
            FROM knowledge_chunks
            ORDER BY embedding <-> :query_vec::vector
            LIMIT :top_k
        """),
        {"query_vec": str(query_vector), "top_k": top_k},
    )
    rows = result.fetchall()
    # Map database row IDs to ALL_CHUNKS indices
    # This works because we seeded in order and IDs start at 1
    return [(row[0] - 1, row[1]) for row in rows]


# ── Main retrieval function ───────────────────────────────────────────────────

async def retrieve(
    db: AsyncSession,
    query: str,
    top_n: int = 4,
) -> list[KnowledgeChunk]:
    """
    LEARN: This is the full hybrid search pipeline in one function.

    Called by the chatbot endpoint on every user message.
    Returns top_n most relevant knowledge chunks.
    These get injected into the LLM's context so it has accurate
    clinical content to reference.

    Steps:
    1. Embed the query (convert to vector)
    2. Semantic search in pgvector
    3. Keyword search in BM25 index
    4. Merge with RRF
    5. Return the actual chunk objects
    """
    # Step 1: embed the query
    query_vector = embed(query)

    # Step 2: semantic search (pgvector)
    semantic_results = await semantic_search(db, query_vector, top_k=10)

    # Step 3: keyword search (BM25, in-memory)
    bm25_index = get_bm25_index()
    keyword_results = bm25_index.search(query, top_k=10)

    # Step 4: merge with RRF
    top_indices = _rrf_merge(semantic_results, keyword_results, top_n=top_n)

    # Step 5: return chunks (guard against index out of range)
    return [ALL_CHUNKS[i] for i in top_indices if i < len(ALL_CHUNKS)]


def format_retrieved_chunks(chunks: list[KnowledgeChunk]) -> str:
    """
    LEARN: Format retrieved chunks for injection into the LLM system prompt.
    We label them clearly so the LLM knows this is retrieved clinical content,
    not its own training data.
    """
    if not chunks:
        return ""

    lines = ["RELEVANT CLINICAL REFERENCE MATERIAL (use this, do not improvise):"]
    for i, chunk in enumerate(chunks, 1):
        lines.append(f"\n[{i}] ({chunk.category.upper()}) {chunk.content}")

    return "\n".join(lines)
