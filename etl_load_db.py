"""
ETL: loads the cleaned vaccination CSVs (produced by clean_data.py) into a
normalized SQLite star-schema database defined in schema.sql.

Usage:
    python3 etl_load_db.py
Produces:
    vaccination.db
"""
import sqlite3
import pandas as pd
import os

BASE = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE, "..", "data")
DB_PATH = os.path.join(BASE, "vaccination.db")
SCHEMA_PATH = os.path.join(BASE, "schema.sql")

if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()
with open(SCHEMA_PATH) as f:
    cur.executescript(f.read())
conn.commit()
print("Schema created.")

# ---------- Load cleaned data -------------------------------------------------
cov_country = pd.read_csv(f"{DATA_DIR}/coverage_country.csv")
cov_region  = pd.read_csv(f"{DATA_DIR}/coverage_region.csv")
cov_global  = pd.read_csv(f"{DATA_DIR}/coverage_global.csv")
inc         = pd.read_csv(f"{DATA_DIR}/incidence.csv")
cases       = pd.read_csv(f"{DATA_DIR}/cases.csv")
intro       = pd.read_csv(f"{DATA_DIR}/intro.csv")
sched       = pd.read_csv(f"{DATA_DIR}/schedule.csv")

def to_int_year(s):
    return pd.to_numeric(s, errors="coerce").astype("Int64")

for df in [cov_country, cov_region, cov_global, inc, cases, intro, sched]:
    df["YEAR"] = to_int_year(df["YEAR"])

# ---------- Build dim_country (merge country identity from all sources, WHO region from intro/schedule) ----------
country_rows = []
for _, r in cov_country[["CODE","NAME"]].drop_duplicates().iterrows():
    country_rows.append((r["CODE"], r["NAME"]))
for _, r in inc[["CODE","NAME"]].drop_duplicates().iterrows():
    country_rows.append((r["CODE"], r["NAME"]))
countries_df = pd.DataFrame(country_rows, columns=["iso3_code","country_name"]).dropna().drop_duplicates(subset=["iso3_code"])

region_map = pd.concat([
    intro[["ISO_3_CODE","WHO_REGION"]].rename(columns={"ISO_3_CODE":"iso3_code"}),
    sched[["ISO_3_CODE","WHO_REGION"]].rename(columns={"ISO_3_CODE":"iso3_code"}),
]).dropna().drop_duplicates(subset=["iso3_code"])

countries_df = countries_df.merge(region_map, on="iso3_code", how="left")
countries_df.to_sql("dim_country_stage", conn, if_exists="replace", index=False)
cur.execute("""INSERT INTO dim_country (iso3_code, country_name, who_region)
               SELECT iso3_code, country_name, WHO_REGION FROM dim_country_stage""")
cur.execute("DROP TABLE dim_country_stage")
conn.commit()
print("dim_country loaded:", cur.execute("SELECT COUNT(*) FROM dim_country").fetchone()[0])

# ---------- dim_year ----------
years = sorted(set(pd.concat([cov_country["YEAR"], cov_region["YEAR"], cov_global["YEAR"],
                               inc["YEAR"], cases["YEAR"], intro["YEAR"], sched["YEAR"]]).dropna().astype(int)))
year_df = pd.DataFrame({"year": years})
year_df["decade"] = (year_df["year"] // 10 * 10).astype(str) + "s"
year_df.to_sql("dim_year", conn, if_exists="append", index=False)
conn.commit()
print("dim_year loaded:", len(years))

# ---------- dim_antigen ----------
antigens = pd.concat([
    cov_country[["ANTIGEN","ANTIGEN_DESCRIPTION"]],
    cov_region[["ANTIGEN","ANTIGEN_DESCRIPTION"]],
    cov_global[["ANTIGEN","ANTIGEN_DESCRIPTION"]],
]).dropna().drop_duplicates(subset=["ANTIGEN"])
antigens.columns = ["antigen_code","antigen_description"]
antigens.to_sql("dim_antigen", conn, if_exists="append", index=False)
conn.commit()
print("dim_antigen loaded:", len(antigens))

# ---------- dim_disease ----------
diseases = pd.concat([
    inc[["DISEASE","DISEASE_DESCRIPTION"]],
    cases[["DISEASE","DISEASE_DESCRIPTION"]],
]).dropna().drop_duplicates(subset=["DISEASE"])
diseases.columns = ["disease_code","disease_description"]
diseases.to_sql("dim_disease", conn, if_exists="append", index=False)
conn.commit()
print("dim_disease loaded:", len(diseases))

# ---------- dim_vaccine (free-text vaccine names from intro/schedule) ----------
vaccines = pd.concat([
    intro[["DESCRIPTION"]].rename(columns={"DESCRIPTION":"vaccine_description"}),
    sched[["VACCINE_DESCRIPTION"]].rename(columns={"VACCINE_DESCRIPTION":"vaccine_description"}),
]).dropna().drop_duplicates()
vaccines.to_sql("dim_vaccine", conn, if_exists="append", index=False)
conn.commit()
print("dim_vaccine loaded:", len(vaccines))

# ---------- lookup maps ----------
country_map  = pd.read_sql("SELECT country_id, iso3_code FROM dim_country", conn).set_index("iso3_code")["country_id"]
year_map     = pd.read_sql("SELECT year_id, year FROM dim_year", conn).set_index("year")["year_id"]
antigen_map  = pd.read_sql("SELECT antigen_id, antigen_code FROM dim_antigen", conn).set_index("antigen_code")["antigen_id"]
disease_map  = pd.read_sql("SELECT disease_id, disease_code FROM dim_disease", conn).set_index("disease_code")["disease_id"]
vaccine_map  = pd.read_sql("SELECT vaccine_id, vaccine_description FROM dim_vaccine", conn).set_index("vaccine_description")["vaccine_id"]

def map_col(df, col, mapping, new_col):
    df[new_col] = df[col].map(mapping)
    return df

# ---------- fact_coverage (country level) ----------
f = cov_country.copy()
f = map_col(f, "CODE", country_map, "country_id")
f = map_col(f, "YEAR", year_map, "year_id")
f = map_col(f, "ANTIGEN", antigen_map, "antigen_id")
f = f.dropna(subset=["country_id","year_id","antigen_id"])
out = f[["country_id","year_id","antigen_id","COVERAGE_CATEGORY","COVERAGE_CATEGORY_DESCRIPTION","TARGET_NUMBER","DOSES","COVERAGE"]]
out.columns = ["country_id","year_id","antigen_id","coverage_category","coverage_category_description","target_number","doses","coverage_pct"]
out.to_sql("fact_coverage", conn, if_exists="append", index=False)
conn.commit()
print("fact_coverage loaded:", len(out))

# ---------- fact_coverage_region ----------
f = cov_region.copy()
f = map_col(f, "YEAR", year_map, "year_id")
f = map_col(f, "ANTIGEN", antigen_map, "antigen_id")
f = f.dropna(subset=["year_id","antigen_id"])
out = f[["NAME","year_id","antigen_id","COVERAGE"]].rename(columns={"NAME":"who_region","COVERAGE":"coverage_pct"})
out.to_sql("fact_coverage_region", conn, if_exists="append", index=False)
conn.commit()
print("fact_coverage_region loaded:", len(out))

# ---------- fact_coverage_global ----------
f = cov_global.copy()
f = map_col(f, "YEAR", year_map, "year_id")
f = map_col(f, "ANTIGEN", antigen_map, "antigen_id")
f = f.dropna(subset=["year_id","antigen_id"])
out = f[["year_id","antigen_id","COVERAGE"]].rename(columns={"COVERAGE":"coverage_pct"})
out.to_sql("fact_coverage_global", conn, if_exists="append", index=False)
conn.commit()
print("fact_coverage_global loaded:", len(out))

# ---------- fact_incidence ----------
f = inc.copy()
f = map_col(f, "CODE", country_map, "country_id")
f = map_col(f, "YEAR", year_map, "year_id")
f = map_col(f, "DISEASE", disease_map, "disease_id")
f = f.dropna(subset=["country_id","year_id","disease_id"])
out = f[["country_id","year_id","disease_id","DENOMINATOR","INCIDENCE_RATE"]]
out.columns = ["country_id","year_id","disease_id","denominator","incidence_rate"]
out.to_sql("fact_incidence", conn, if_exists="append", index=False)
conn.commit()
print("fact_incidence loaded:", len(out))

# ---------- fact_cases ----------
f = cases.copy()
f = map_col(f, "CODE", country_map, "country_id")
f = map_col(f, "YEAR", year_map, "year_id")
f = map_col(f, "DISEASE", disease_map, "disease_id")
f = f.dropna(subset=["country_id","year_id","disease_id"])
out = f[["country_id","year_id","disease_id","CASES"]]
out.columns = ["country_id","year_id","disease_id","cases"]
out.to_sql("fact_cases", conn, if_exists="append", index=False)
conn.commit()
print("fact_cases loaded:", len(out))

# ---------- fact_vaccine_intro ----------
f = intro.copy()
f = map_col(f, "ISO_3_CODE", country_map, "country_id")
f = map_col(f, "YEAR", year_map, "year_id")
f = map_col(f, "DESCRIPTION", vaccine_map, "vaccine_id")
f = f.dropna(subset=["country_id","year_id","vaccine_id"])
out = f[["country_id","year_id","vaccine_id","INTRO"]].rename(columns={"INTRO":"introduced"})
out.to_sql("fact_vaccine_intro", conn, if_exists="append", index=False)
conn.commit()
print("fact_vaccine_intro loaded:", len(out))

# ---------- fact_schedule ----------
f = sched.copy()
f = map_col(f, "ISO_3_CODE", country_map, "country_id")
f = map_col(f, "YEAR", year_map, "year_id")
f = map_col(f, "VACCINE_DESCRIPTION", vaccine_map, "vaccine_id")
f = f.dropna(subset=["country_id","year_id","vaccine_id"])
out = f[["country_id","year_id","vaccine_id","SCHEDULEROUNDS","TARGETPOP","TARGETPOP_DESCRIPTION","GEOAREA","AGEADMINISTERED","SOURCECOMMENT"]]
out.columns = ["country_id","year_id","vaccine_id","schedule_rounds","target_pop","target_pop_description","geoarea","age_administered","source_comment"]
out.to_sql("fact_schedule", conn, if_exists="append", index=False)
conn.commit()
print("fact_schedule loaded:", len(out))

conn.close()
print("\nETL complete ->", DB_PATH)
