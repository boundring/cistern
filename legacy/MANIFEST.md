# Cistern Legacy Manifest — collected 2026-08-31

## Moved (PRIMARY — most recent, most complete dev copy)

| Original path | New path | Description |
|---|---|---|
| /home/bricker/Projects/cistern-share/cistern-2.0.0/cistern.el | legacy/cistern-share/cistern-2.0.0/cistern.el | v2.0.0 game source: single-file Emacs Lisp tile-map sanitation sim (1140 lines) |
| /home/bricker/Projects/cistern-share/cistern-2.0.0/README.md | legacy/cistern-share/cistern-2.0.0/README.md | v2 README: rules, controls, install |
| /home/bricker/Projects/cistern-share/cistern-2.0.0/DESIGN.md | legacy/cistern-share/cistern-2.0.0/DESIGN.md | v2 design notes: principles and how each became code |
| /home/bricker/Projects/cistern-share/cistern-2.0.0/screenshot.png | legacy/cistern-share/cistern-2.0.0/screenshot.png | Screenshot of v2 running in Emacs |
| /home/bricker/Projects/cistern-share/cistern-2.0.0.zip | legacy/cistern-share/cistern-2.0.0.zip | Packaged release archive of v2.0.0 (same 4 files) |
| /home/bricker/Projects/cistern-share/cistern-1.0.0/cistern.el | legacy/cistern-share/cistern-1.0.0/cistern.el | v1.0.0 game source (759 lines): earlier iteration with globals-heavy design |
| /home/bricker/Projects/cistern-share/cistern-1.0.0/README.md | legacy/cistern-share/cistern-1.0.0/README.md | v1 README |
| /home/bricker/Projects/cistern-share/cistern-1.0.0/DESIGN.md | legacy/cistern-share/cistern-1.0.0/DESIGN.md | v1 design notes |
| /home/bricker/Projects/cistern-share/cistern-1.0.0.zip | legacy/cistern-share/cistern-1.0.0.zip | Packaged release archive of v1.0.0 |

## Duplicates NOT moved (left in place)

| Path | Reason |
|---|---|
| /home/bricker/.emacs.d/lisp/cistern.el | Kept in place: byte-identical to the primary cistern.el already in the repo, and the installed/autoloaded copy referenced by init.el:620-621 — moving it would break the user's Emacs |
| /home/bricker/.emacs.d/lisp/cistern.elc | Byte-compiled artifact of the above |

## Notes

- No system-installed copy found under /usr (checked /usr/share/emacs, /usr/local/share/emacs, ~/.local/share/emacs; system site-lisp contains only subdirs.el). "Built into the system emacs" = the user's ~/.emacs.d autoload, not a system path.
- /home/bricker/.emacs.d/init.el lines 620-621 reference ~/.emacs.d/lisp/cistern.el (autoload) — left untouched.
- Version history: v1 (globals + render reaching into sim state, "worked badly") → v2 rebuild (clean layering), per DESIGN.md.
