-- Provenance tables. Their (country_code, source_id, source_date) key is the
-- target of a composite foreign key from every business entity, so a row can
-- only reference a source run from its own country.

CREATE TABLE IF NOT EXISTS iris_core.source_run (
    source_run_id BIGSERIAL PRIMARY KEY,
    country_code  TEXT        NOT NULL,
    source_id     TEXT        NOT NULL,
    source_date   DATE        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    status        TEXT        NOT NULL DEFAULT 'completed',

    CONSTRAINT ck_source_run_country_code CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_source_run_source_id    CHECK (btrim(source_id) <> ''),
    CONSTRAINT ck_source_run_status       CHECK (status IN ('started', 'completed', 'failed')),
    CONSTRAINT uq_source_run_key UNIQUE (country_code, source_id, source_date)
);

CREATE TABLE IF NOT EXISTS iris_core.evidence (
    evidence_id   BIGSERIAL PRIMARY KEY,
    country_code  TEXT        NOT NULL,
    source_id     TEXT        NOT NULL,
    source_date   DATE        NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    evidence_type TEXT        NOT NULL,
    reference     TEXT,

    CONSTRAINT ck_evidence_country_code CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_evidence_type         CHECK (btrim(evidence_type) <> ''),
    CONSTRAINT uq_evidence_key UNIQUE (country_code, source_id, source_date, evidence_type),
    CONSTRAINT fk_evidence_source_run
        FOREIGN KEY (country_code, source_id, source_date)
        REFERENCES iris_core.source_run (country_code, source_id, source_date)
);
