# Ds--Vaccination-project

# 💉 Global Vaccination Data Analysis & Visualization

Exploratory data analysis, a normalized SQL database, and Power BI–style dashboards built from WHO/UNICEF global immunization data — covering **214 countries**, **69 vaccines**, **13 diseases**, from **1980–2023**.

> **Domain:** Public Health & Epidemiology
> **Skills:** Python, Pandas, SQL, Data Cleaning, EDA, Data Visualization, Power BI Dashboard Design

---

## 📌 Project Summary

Vaccination programs are one of public health's biggest success stories, but coverage gaps, dose drop-off, and regional disparities still leave populations at risk. This project cleans and analyzes five linked WHO/UNICEF datasets to answer:

- How has global vaccination coverage changed over time, and did COVID-19 disrupt it?
- What's the drop-off rate between the 1st and 3rd dose of a vaccine schedule?
- Which WHO regions lag on coverage — and which lead on introducing new vaccines?
- Does higher coverage actually correlate with lower disease incidence?
- Which countries report high coverage but still experience outbreaks?

Full findings are in the notebook and report below — headline result: reported national coverage rose steadily through 2019, dropped during the pandemic and hasn't fully recovered, the African Region trails on sustained coverage while leading on new-vaccine introduction, and several high-coverage countries (Samoa, Madagascar, Ukraine) still had major measles outbreaks — proof that a national average can hide real risk.

---

## 📂 Repository Structure

```
├── Vaccination_EDA_Analysis.ipynb              # Full EDA notebook (cleaning, 15 charts, insights)
├── Vaccination_PowerBI_Dashboard_Report.docx   # Dashboard designs, question mapping, DAX measures
├── Vaccination_Interactive_Dashboard.html      # Live interactive dashboard (open in any browser)
├── Video_Explanation_Cheat_Sheet.md            # Script used for the walkthrough video
├── sql/
│   ├── schema.sql          # Star-schema DDL (5 dimension + 7 fact tables)
│   ├── etl_load_db.py      # Python ETL: cleans raw Excel files -> loads into SQLite
│   ├── queries.sql         # 10 analytical SQL queries, each mapped to a project question
│   └── vaccination.db      # Populated SQLite database (~700,000 rows), ready to query
└── README.md
```

---

## 🗃️ Data Sources

Five WHO/UNICEF tables (raw `.xlsx` files, cleaned during ETL):

| Table | Grain | Rows (raw) |
|---|---|---|
| Coverage | Country/Region/Global × Year × Antigen | ~400,000 |
| Incidence Rate | Country × Year × Disease | ~85,000 |
| Reported Cases | Country × Year × Disease | ~85,000 |
| Vaccine Introduction | Country × Year × Vaccine | ~138,000 |
| Vaccine Schedule | Country × Year × Vaccine × Dose | ~8,000 |

**Known limitation:** none of the five tables include gender, education level, income/socioeconomic group, urban/rural classification, population density, or a monthly date field. Brief questions depending on these are explicitly flagged as "not available" rather than answered with assumptions — see the report's Section 5 (Data Limitations).

---

## 🧱 Data Model

A star schema normalizes the raw exports into 5 dimension tables (`dim_country`, `dim_year`, `dim_antigen`, `dim_disease`, `dim_vaccine`) and 7 fact tables (`fact_coverage`, `fact_coverage_region`, `fact_coverage_global`, `fact_incidence`, `fact_cases`, `fact_vaccine_intro`, `fact_schedule`). Full DDL in [`schema.sql`](schema.sql).

---

## 🚀 How to Explore This Project

**1. Read the analysis** — open `Vaccination_EDA_Analysis.ipynb` in Jupyter, VS Code, or Google Colab. It's already executed, so all charts and outputs are visible without re-running anything.

**2. Play with the dashboard** — download `Vaccination_Interactive_Dashboard.html` and double-click it (opens in any browser, no installation needed). 5 tabs: Global KPI, Coverage Trends, Regional Disparities, Coverage vs. Incidence, Vaccine Introduction.

**3. Query the database** — open `sql/vaccination.db` in [DB Browser for SQLite](https://sqlitebrowser.org/) (free, no SQL server install needed) and run the queries in `sql/queries.sql`, or browse the tables directly.

**4. Read the business report** — `Vaccination_PowerBI_Dashboard_Report.docx` has the full Power BI dashboard specs (visuals + DAX measures), the question-to-dashboard mapping table, and the challenges/solutions write-up.

**5. Rebuild the database yourself (optional)** — `sql/etl_load_db.py` re-cleans the raw Excel files and rebuilds `vaccination.db` from scratch:
```bash
pip install pandas openpyxl
python3 sql/etl_load_db.py
```

---

## 📊 Key Findings

- Global DTP3/MCV1/POL3 coverage rose from ~72% (2000) to ~86% (2019), dropped to ~81% during 2020–2021 (COVID-19), and sits at ~84% in 2023 — not yet fully recovered.
- DTP dose-1→dose-3 drop-off narrowed from 6 points (2009) to 4 points (2018), then widened back to 5 points post-pandemic.
- Measles 2nd-dose (booster) coverage nearly doubled: 40% (2009) → 74% (2023).
- The **African Region** trails all WHO regions on sustained DTP3 coverage (74% vs. 95% in Europe) — but leads on introducing new vaccines like Rotavirus (81% of countries vs. 49% in Europe).
- **HPV vaccination** is the largest coverage gap of all 69 tracked antigens, at just 5–20% globally.
- Several countries with ≥90% reported measles coverage (Samoa, Tonga, Madagascar, DR Congo, Ukraine) still experienced major outbreaks, showing that national averages can mask real risk.

---

## 🛠️ Tech Stack

`Python` · `Pandas` · `Matplotlib` / `Seaborn` · `SQLite` · `SQL` · `HTML/CSS/JS` (dashboard) · `Chart.js` · `Power BI` (dashboard design)

---

## ⚠️ Note on Power BI

No `.pbix` file is included, since Power BI Desktop wasn't available in the development environment. Every dashboard page is fully specified (visuals + DAX measures) in the report against the real SQL database, and the HTML dashboard is a working, faithful preview of the same 5 pages — built from identical data — until it's rebuilt natively in Power BI.

---

## 👤 Author
Sita Bharatula 

