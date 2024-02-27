---
title: Release Notes
---

# Release Notes

{% for release in releases | selectattr("is_initial_development", "false") -%}
## {{ release.version }}{% if not release.is_released %} (Unreleased){% endif %}
{% for section in release.sections %}
**{{ section.title }}**

{% for change in section.changes | reverse -%}
- {{ change.description }}{% if change.scope %}{{ change.scope }}{% endif %}
{% endfor %}{% endfor %}
{% endfor %}
