---
title: Content Quality Dashboard
layout: page
permalink: /docs/quality/
summary: "Generated quality checks for metadata, references, study cards, and operational study coverage."
tags:
  - study
  - quality
  - maintenance
---

# Content Quality Dashboard

This page is generated from the built Jekyll page collection. It is meant to make content drift visible before a page silently loses metadata, references, or study practice hooks.

{% include quality-report.html %}

## Study Cards

<div class="study-card-grid">
  {% include study-card.html question="What does the quality dashboard catch quickly?" answer="Missing summaries, tags, references, and study card sections across generated docs pages." %}
  {% include study-card.html question="Why keep the dashboard generated?" answer="It turns content conventions into visible site output instead of relying only on memory." %}
  {% include study-card.html question="What should still be checked by tests?" answer="Required front matter, search indexing, navigation coverage, references, and high-risk rendered behavior." %}
</div>

## References

- [Jekyll Pages](https://jekyllrb.com/docs/pages/)
- [Jekyll Data Files](https://jekyllrb.com/docs/datafiles/)
- [Cross-Topic Study Paths](/docs/study-paths/)
