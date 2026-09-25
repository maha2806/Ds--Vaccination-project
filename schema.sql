-- ============================================================================
-- Global Vaccination Data Warehouse — Star Schema DDL
-- Portable ANSI SQL (tested on SQLite; compatible with PostgreSQL/MySQL with
-- minor type adjustments e.g. INTEGER PRIMARY KEY AUTOINCREMENT -> SERIAL)
-- ============================================================================

-- ---------- DIMENSION TABLES ----------------------------------------------

CREATE TABLE dim_country (
    country_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    iso3_code       TEXT UNIQUE NOT NULL,
    country_name    TEXT NOT NULL,
    who_region      TEXT
);

CREATE TABLE dim_year (
    year_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    year            INTEGER UNIQUE NOT NULL,
    decade          TEXT
);

CREATE TABLE dim_antigen (
    antigen_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    antigen_code        TEXT UNIQUE NOT NULL,
    antigen_description TEXT
);

CREATE TABLE dim_disease (
    disease_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    disease_code        TEXT UNIQUE NOT NULL,
    disease_description TEXT
);

CREATE TABLE dim_vaccine (
    vaccine_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    vaccine_description TEXT UNIQUE NOT NULL
);

-- ---------- FACT TABLES -----------------------------------------------------

-- Country-level vaccination coverage (grain: country x year x antigen x coverage_category)
CREATE TABLE fact_coverage (
    fact_id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    country_id                   INTEGER NOT NULL REFERENCES dim_country(country_id),
    year_id                      INTEGER NOT NULL REFERENCES dim_year(year_id),
    antigen_id                   INTEGER NOT NULL REFERENCES dim_antigen(antigen_id),
    coverage_category            TEXT,
    coverage_category_description TEXT,
    target_number                REAL,
    doses                        REAL,
    coverage_pct                 REAL
);

-- WHO-region aggregate coverage (grain: who_region x year x antigen)
CREATE TABLE fact_coverage_region (
    fact_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    who_region     TEXT NOT NULL,
    year_id        INTEGER NOT NULL REFERENCES dim_year(year_id),
    antigen_id     INTEGER NOT NULL REFERENCES dim_antigen(antigen_id),
    coverage_pct   REAL
);

-- Global aggregate coverage (grain: year x antigen)
CREATE TABLE fact_coverage_global (
    fact_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    year_id        INTEGER NOT NULL REFERENCES dim_year(year_id),
    antigen_id     INTEGER NOT NULL REFERENCES dim_antigen(antigen_id),
    coverage_pct   REAL
);

-- Disease incidence (grain: country x year x disease)
CREATE TABLE fact_incidence (
    fact_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    country_id      INTEGER NOT NULL REFERENCES dim_country(country_id),
    year_id         INTEGER NOT NULL REFERENCES dim_year(year_id),
    disease_id      INTEGER NOT NULL REFERENCES dim_disease(disease_id),
    denominator     TEXT,
    incidence_rate  REAL
);

-- Reported case counts (grain: country x year x disease)
CREATE TABLE fact_cases (
    fact_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    country_id  INTEGER NOT NULL REFERENCES dim_country(country_id),
    year_id     INTEGER NOT NULL REFERENCES dim_year(year_id),
    disease_id  INTEGER NOT NULL REFERENCES dim_disease(disease_id),
    cases       REAL
);

-- Vaccine introduction status (grain: country x year x vaccine)
CREATE TABLE fact_vaccine_intro (
    fact_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    country_id  INTEGER NOT NULL REFERENCES dim_country(country_id),
    year_id     INTEGER NOT NULL REFERENCES dim_year(year_id),
    vaccine_id  INTEGER NOT NULL REFERENCES dim_vaccine(vaccine_id),
    introduced  TEXT   -- 'Yes' / 'No'
);

-- Vaccine schedule (grain: country x year x vaccine x schedule round)
CREATE TABLE fact_schedule (
    fact_id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    country_id              INTEGER NOT NULL REFERENCES dim_country(country_id),
    year_id                 INTEGER NOT NULL REFERENCES dim_year(year_id),
    vaccine_id              INTEGER NOT NULL REFERENCES dim_vaccine(vaccine_id),
    schedule_rounds         TEXT,
    target_pop              TEXT,
    target_pop_description  TEXT,
    geoarea                 TEXT,
    age_administered        TEXT,
    source_comment          TEXT
);

-- ---------- INDEXES ----------------------------------------------------------
CREATE INDEX idx_fact_coverage_country_year ON fact_coverage(country_id, year_id);
CREATE INDEX idx_fact_coverage_antigen      ON fact_coverage(antigen_id);
CREATE INDEX idx_fact_incidence_country_year ON fact_incidence(country_id, year_id);
CREATE INDEX idx_fact_incidence_disease     ON fact_incidence(disease_id);
CREATE INDEX idx_fact_cases_country_year    ON fact_cases(country_id, year_id);
CREATE INDEX idx_fact_intro_country_year    ON fact_vaccine_intro(country_id, year_id);
CREATE INDEX idx_fact_schedule_country_year ON fact_schedule(country_id, year_id);
