# Analysis plan — influenza season-burden forecast

*Registered before fitting (McElreath Ch17 discipline: the plan is written first;
deviations are allowed but must be documented here with a dated note).*

Status: **Step 1 under review** · Started 2026-08-21 · Branch `claude/repo-setup-testing-gaz8w9`

## 1. Estimand

**Θ\_c = the cumulative influenza ILI+ of country c over the 2026/2027 season** —
influenza-attributable ILI consultations per 100 000 population, summed over the
weeks of the burden window, all ages (`age_total`):

```
Θ_c = Σ_w  ILI⁺_{c,w}     for season weeks w with dates in [1 Oct 2026, 31 May 2027]
```

where ILI⁺ = ILI consultation rate × sentinel influenza test positivity
(the `ili_plus_sentinel` stream in `models_in$data_timeseries_long`).

- **Target countries**: every country with ≥1 season of sentinel ILI+ history
  (24 countries); forecasts for the 7 of them that did not report in 2025/26
  are flagged as extrapolations.
- Θ\_c is a **latent full-window sum**: weeks a country fails to report still have
  influenza — the estimand is not "the sum of whatever gets reported".
- This is a *descriptive/predictive* estimand (what will the burden be), not a
  causal one; no intervention claims are attached to it.

## 2. Data basis (verified against the pipeline, snapshots to 2026-05-13)

| Source stream | Seasons | Countries | Weekly NA share |
|---|---|---|---|
| `ili_plus_sentinel` (ERVISS) | 2021/22 – 2025/26 | 17–24 | 5–32% |
| `ili_plus_respicompass` (hub history) | 2014/15 – 2023/24 | 22–26 | 12–62% |

Two measurement systems, three overlap seasons (2021/22–2023/24) → the long
history is usable only through an explicit **stream-bridge** (system offset)
learned on the overlap. 2020/21 is a structural anomaly (COVID) in both.

## 3. Causal / measurement structure (DAG)

Figure 1.1. The estimand is a functional of latent influenza-attributable
consultations; ILI+ measures it through two noisy channels (consultation rate;
positivity from a finite test sample) and one selection channel (reporting).
`dagitty` equivalent (run locally; the container lacks the V8 dependency):

```r
dagitty::dagitty('dag {
  Season_drivers [latent]  Incidence [latent]  Care_seeking [latent]  Other_ILI [latent]
  Reporting  ILI_rate_obs  Tests_N  Positivity_obs  ILIplus_obs  Burden [outcome]
  Season_drivers -> Incidence
  Incidence -> ILI_rate_obs        Care_seeking -> ILI_rate_obs   Other_ILI -> ILI_rate_obs
  Incidence -> Positivity_obs      Other_ILI -> Positivity_obs    Tests_N -> Positivity_obs
  ILI_rate_obs -> ILIplus_obs      Positivity_obs -> ILIplus_obs
  Reporting -> ILI_rate_obs        Reporting -> Positivity_obs
  Incidence -> Burden              Care_seeking -> Burden
}')
```

Key implications: (i) ILI+ inherits error from *both* factors — small test
denominators make positivity noisy (Ch15 measurement-error logic); (ii)
reporting is plausibly *not* random w.r.t. season phase → missing weeks cannot
be ignored silently; (iii) care-seeking sits inside the estimand (ILI+ is a
consultation-based burden measure, by design).

## 4. Estimator ladder (fit in this order; compare, don't select)

- **E0 — carry-forward baseline**: Θ\_c(2026/27) = observed burden 2025/26 (or the
  country's last complete season), uncertainty from historical season-to-season
  log-ratios. Repairs and reuses the parked `model_last_year_burden.R` scaffold
  (known bug: `load(` → `log(` at line 40).
- **E1 — multilevel season-level model**: log Θ\_cs ~ Normal(µ\_cs, σ);
  µ\_cs = ᾱ + α\_c + γ\_s + δ·source\_cs, with partial pooling over countries
  (α\_c) and seasons (γ\_s), a stream-bridge δ learned on the overlap seasons,
  and season-completeness entering as measurement error on observed Θ\_cs.
  Priors set in Step 2 by prior predictive simulation, non-centered if HMC asks.
- **E2 (later, separate plan)**: weekly latent-curve model → integrate the curve;
  eventually the mechanistic SIR route (Ch16 template).

Fitting: `quap`-class approximations are insufficient for E1's hierarchy → Stan
on the local machine (container has no Stan; code will be written runnable-local).

## 5. Validation & scoring

- **Fake-data first**: simulate the E1 generative model with known parameters,
  verify recovery, before touching real data (Gelman §4.1).
- **Backtest (leave-future-out)**: refit with data up to season t−1, forecast
  season t, for t ∈ {2022/23, 2023/24, 2024/25, 2025/26}; score by log score and
  50%/89% interval coverage against completeness-adjusted observed burden.
  Pointwise WAIC/PSIS is *not* the headline criterion (autocorrelated panel).
- Report full posteriors; nested 50/89% compatibility intervals; no point
  estimate without a stated loss.

## 6. Workflow steps (one pause per step)

| Step | Deliverable | Status |
|---|---|---|
| 1 | Estimand, DAG, data-landscape figures 1.1–1.4 | **this document** |
| 2 | Generative model + priors; prior predictive figures | pending sign-off |
| 3 | E0 baseline + backtest harness | |
| 4 | E1 fit; HMC diagnostics figures | |
| 5 | Criticism: PPC on season shape statistics, backtest scores, E0-vs-E1 | |
| 6 | 2026/27 forecast presentation | |

## 7. Decisions

**Taken (revisit only with a dated note):** pathogen = influenza; outcome
stream = sentinel ILI+ `age_total`; burden window = 1 Oct – 31 May; 2020/21
included in data figures, excluded from season-effect pooling (structural
anomaly, Student-t / robust handling assessed in Step 5).

**Open — to confirm at the Step 1 pause:**
1. Burden window 1 Oct–31 May (vs ISO weeks 40–20): acceptable?
2. Season-completeness rule for *training* outcomes: propose ≥70% of window
   weeks reported → season usable, completeness carried as measurement error;
   sensitivity at ≥80%.
3. Use the RespiCompass history through the stream-bridge (recommended) or
   sentinel-only (cleaner, but 4 usable seasons per country)?
4. Data refresh: snapshots end 2026-05-13 — fine for a pre-season forecast;
   refresh (`regenerate=T, new_from_online=T`) before Step 6, or now?
