---
title: "Table calculations"
author: "markbreak"
role: chapter
---

# Tables that calculate

A cell that starts with `=` is a calculation. Every other cell is a literal.

| Item | Qty | Pack price | Factor (hidden) | Line total |
|------|-----|------------|-----------------|------------|
| Apples | 2 | 3 | 10 | =C2*C3*C4 |
| Pears | 4 | 5 | 2 | =@Qty*@{Pack price}*@Factor |
| Total | =SUM(C2R1:C2R2) | =AVERAGE(C3R1:C3R2) | | =SUM(C5R1:C5R2) |

The `Factor` column is a hidden helper. Readers see only its effect.

| Measure | Amount |
|---------|--------|
| Alpha | 2 |
| Beta | 4 |
| Gamma | 6 |
| Smallest | =MIN(C2R1:C2R3) |
| Largest | =MAX(C2R1:C2R3) |
| Counted | =COUNT(C2R1:C2R3) |
| Product | =PRODUCT(C2R1:C2R3) |
| Specific | =C2R2*180 |
| Percent | =C2R1*50% |
| Literal | C2R2*180 |
| Escaped | '=C2R2 |
| Broken | =C2R1/0 |
| Missing | =C9R9 |

Rows are named by their first cell, so a cell can be named from both sides.

| Item | Qty | Price |
|------|-----|-------|
| Apples | 2 | 3 |
| Pears | 4 | 5 |
| Cherry picking | =@Qty@Pears | |
| Copied | =@Qty@{Cherry picking} | |
| Named cell | =@Qty@Apples*@Price@Apples | |
| By number | =C3@Pears | |
| Row sum | =SUM(@Pears) | |
| Row range | =SUM(@Apples:@Pears) | |

| Left | Right |
|------|-------|
| =C2R1 | =C1R1 |
