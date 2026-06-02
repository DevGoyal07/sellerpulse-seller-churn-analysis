# PRD: Seller Activation — Reducing Early Churn on the Marketplace
**Product:** SellerPulse · **Author:** [Your name] · **Status:** Draft · **Date:** [date]

> *Note: this PRD is built on analysis of the Olist Brazilian E-Commerce dataset (~100K orders, ~3K sellers). "Activation" is measured from a seller's first sale onward, as the dataset records first sale rather than signup — see Limitations.*

---

## 1. Problem statement
New sellers churn early and fast. **40.5% of new sellers never make a second sale within 30 days of their first.** Every seller lost at this stage represents acquisition cost spent with near-zero return — the seller never reaches the order volume where they become profitable to the marketplace or sticky enough to stay.

Early activation is the highest-leverage point in the seller lifecycle: a seller who reaches a second sale quickly is far more likely to stay active through day 90. Closing even part of the 40.5% gap compounds into a materially larger active-seller base.

## 2. Why now / why this matters
- **Acquisition is expensive; churn wastes it.** A 40.5% pre-2nd-sale drop means nearly half of seller-acquisition spend produces no durable seller.
- **Active sellers drive GMV and selection.** More retained sellers = more listings, more selection, better buyer experience — a marketplace flywheel.
- **The drop-off is concentrated and addressable** (see §4), which means targeted intervention is feasible rather than a vague "improve onboarding."

## 3. Goals & non-goals
**Goals**
- Increase the share of new sellers reaching a 2nd sale within 30 days.
- Identify and support at-risk sellers *before* they go dormant.
- Do this without degrading delivery quality or buyer satisfaction.

**Non-goals**
- Seller *acquisition* (getting new sellers to sign up) — out of scope; this is about activating the ones we already have.
- Buyer-side retention.
- Pricing/commission strategy.

## 4. Key findings (the evidence)

**Finding 1 — Headline churn.** 40.5% of new sellers churn before a 2nd sale within 30 days.

**Finding 2 — Churn concentrates in low-frequency categories.** The worst-churn categories are:

| Category | Sellers | Churn before 2nd sale |
|---|---|---|
| garden_tools | 94 | 51.1% |
| musical_instruments | 35 | 51.4% |
| books_general_interest | 36 | 58.3% |

These are **considered-purchase, low-repeat-frequency** categories. Buyers don't purchase guitars, books, or garden tools repeatedly in a short window — so a seller's odds of a *fast* second sale are partly a function of category demand, not just seller effort. **Implication:** early churn is not one problem but two — a *seller-readiness* problem and a *category-demand* problem — and the intervention must differ by cause. (Lead with garden_tools as the primary case: 94 sellers makes it the most statistically robust of the three.)

**Finding 3 — At-risk segment is identifiable.** Using a 0–100 seller-health score (recency, order velocity, delivery SLA, review score), **646 sellers (~25% of the base) fall in the at-risk band** and can be flagged within their first 30 days for proactive intervention. This is a concrete, sized target list for the seller-growth team — not a vague "improve onboarding."

## 5. Target user & segments
**Primary user of this product:** the marketplace's **seller-growth / category-ops team**, who need to know *which* new sellers are slipping and *why*, early enough to act.

**Seller segments to serve:**
- **Slow-start sellers** — low order velocity in days 0–30 (seller-readiness problem).
- **Low-demand-category sellers** — concentrated in low-repeat categories (demand problem).
- **Reliability-risk sellers** — poor delivery SLA / low reviews dragging their visibility.

## 6. Proposed interventions (RICE-prioritized)

> RICE = (Reach × Impact × Confidence) ÷ Effort. Scores below are estimates to be refined with the team; the *reasoning* is the point.

**Intervention A — Early-seller activation nudges (days 0–30).**
Triggered for slow-start sellers: in-app + email prompts guiding next actions (improve listing, run a first promotion, complete catalog). Targets the seller-readiness slice of churn.
*Reach: high (all new sellers) · Impact: medium · Confidence: medium · Effort: low.* **Likely #1 — best effort-to-reach ratio.**

**Intervention B — Delivery-SLA support for reliability-risk sellers.**
Flag sellers with poor on-time delivery early; offer logistics guidance / partner support before bad reviews compound. Protects the guardrail metrics while helping sellers survive.
*Reach: medium · Impact: high · Confidence: medium · Effort: medium.*

**Intervention C — Category-specific activation playbook for low-repeat categories (start: garden_tools).**
For demand-constrained categories, shift the goal from "fast 2nd sale" to demand-generation: category-level promotion, cross-listing prompts, realistic seller expectation-setting. Targets the category-demand slice.
*Reach: low (specific categories) · Impact: medium · Confidence: lower · Effort: medium.* **Likely #3 — narrower, more experimental.**

## 7. Metrics framework

**North Star metric:** % of new sellers reaching a 2nd sale within 30 days. *(Directly inverts the 40.5% churn finding — if interventions work, this rises.)*

**Input/driver metrics:** order velocity in days 0–30; time-to-second-sale; at-risk-flag conversion (do flagged sellers recover?).

**Guardrail metrics (must not degrade):**
- Average delivery SLA (on-time rate)
- Average review score
*Rationale: pushing sellers for faster volume must not come at the cost of reliability or buyer satisfaction — that would trade short-term activation for long-term marketplace health.*

## 8. The seller-health score (methodology)
A 0–100 composite flagging at-risk sellers, built from four components, each normalized 0–100 then weighted:

| Component | Signal | Weight | Why this weight |
|---|---|---|---|
| Recency | days since last sale (inverted) | 0.30 | Strongest *leading* indicator of churn — a seller going quiet is the earliest warning that they're about to drop off. |
| Order velocity | sales per observable week | 0.30 | Momentum signal — sellers gaining sales velocity are building the habit and order base that keep them active. |
| Delivery SLA | % on-time vs. estimate | 0.20 | A quality/reliability signal; matters, but it lags activity — a seller can deliver on time once and still go dormant. |
| Review score | avg review (1–5) | 0.20 | A quality signal, weighted equally with delivery; important for long-term value but a weaker *short-term* churn predictor. |

> **Weighting rationale (the core product-judgment decision).** The score's job is to *predict churn*, so it weights **activity signals (recency + velocity) above quality signals (delivery + reviews)**. The reasoning: a seller can earn a perfect review on a single sale and still never sell again — quality signals lag, while going quiet is the earliest and most direct sign of churn. An earlier version weighted quality highest; it was revised after recognizing that quality indicators describe how good a seller is *when they sell*, not whether they'll *keep* selling. Quality still carries 40% combined weight, because poor delivery and reviews suppress a seller's marketplace visibility, which upstream-starves them of orders.

## 9. Limitations & assumptions
- **Signup vs. first sale:** Olist records first *sale*, not signup, so "activation" starts at first sale. Real onboarding churn (signup → first sale) is invisible here and would likely make total early churn *higher*.
- **Observation censoring:** sellers without a full 90-day observation window are excluded from the 90-day funnel, so retention is not understated. (Handled in analysis.)
- **Small categories:** books (36) and instruments (35) have small samples; treat as corroborating, not headline.
- **Historical dataset (2016–2018):** patterns are illustrative of marketplace dynamics, not current.

## 10. Open questions
- Is 30 days the right activation window, or should it vary by category purchase-frequency?
- Should the health score be category-relative (graded against category peers) rather than absolute?
- How would we A/B test Intervention A without contaminating cohorts?
