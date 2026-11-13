---
title: "Roles and breaks"
subtitle: "MarkBreak fixture"
author: "markbreak"
role: dedication
---

# For those who stayed

A dedication is not a chapter. YAML `role: dedication` must survive the filter as a Div.

\newpage

Body after the break still belongs to this file’s role.

# After the gates

A second role is a second file with its own YAML `role:`.

//---

# Still this file

Authoring `//---` MUST become a Docx page break.
