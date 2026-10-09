# Native interface criteria

Reviewed against Apple's current Human Interface Guidelines on October 9, 2026. The criteria below apply that guidance to this compact CPU utility; the exact layout and sampling interval are product decisions.

## CPU display

- Keep the current CPU percentage easy to read. A line chart adds the recent trend; it does not replace the number.
- Use the capacity of the entire Mac as the common 0–100 percent scale for both history and app/process bars. Start bars at zero. Do not rescale individual rows or exaggerate changes by changing the history scale.
- Identify the history interval and CPU units. Keep grid lines sparse and align the plot with surrounding content.
- Draw only measured data. Distinguish collecting data, unavailable readings, and a measured zero. Do not draw a connection across a known interruption in sampling.
- Keep numbers beside bars so people can compare both magnitude and exact values without interaction or color interpretation.
- Give the history a VoiceOver description of its purpose, time interval, scale, and measured values or trend summary. Avoid dozens of repetitive navigation stops and repeated unsolicited announcements.
- Render on new samples. No continuous animation or animation between measurements.

Apple recommends line marks for changes over time, bar marks for category comparisons, meaningful fixed scales, clear contextual labels, and accessible chart summaries. See [Charts](https://developer.apple.com/design/human-interface-guidelines/charts).

## Process list and controls

- Retain the native outline and disclosure triangles for app/process hierarchy. Keep selected-row feedback, keyboard navigation, and selection identity through new samples.
- Use short column headings and readable names. Provide the complete name or executable details when truncation is needed.
- Let people search for an app or process without losing the meaning of a group selection. Clearly show an empty result and provide a simple way to clear the search.
- Use regular native search fields, buttons, menus, and focus rings. Keep selected-process Quit and Force Quit actions explicit. Show their existing confirmation before signalling.
- Keep app-level settings and infrequent commands out of the main data area when a native menu can provide them clearly.
- Support Command-F to focus search and standard text editing shortcuts. Provide the native Edit menu for search-field Cut, Copy, Paste, and Select All.

Apple recommends outline views for hierarchical Mac data, concise text, descriptive column headings, standard command placement, and familiar keyboard shortcuts. See [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar), and [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos).

## Readability and compact presentation

- Use the system font, with 13-point body text as the baseline for essential rows. Keep lower-priority text succinct; use size and weight to clarify importance.
- Use system semantic colors and verify light, dark, and Increase Contrast appearances. Do not convey state only through color, bar length, or a tooltip.
- Keep native controls comfortably selectable and separated. Apple's macOS guidance gives 28 by 28 points as the default control target and 20 by 20 points as the minimum.
- Verify VoiceOver names and values, search editing, table navigation, disclosure, action focus, and dismissal with the keyboard.
- Keep the panel bounded to its temporary task. Settings open separately. The search, live hierarchy, and history justify content richer than a simple menu; a plain command list should use a menu.

Apple explicitly notes that macOS does not support Dynamic Type. System fonts provide native typography, but are not a substitute for testing legibility or adding an explicit larger-text option if needed. See [Typography](https://developer.apple.com/design/human-interface-guidelines/typography), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), and [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers).

## Source verification

Apple's public documentation pages sometimes return only a JavaScript shell to text clients. Their corresponding official DocC payloads were read directly at `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json` for all seven linked pages. The Typography payload includes changes through December 16, 2025; Accessibility includes changes through June 9, 2025. These are the page change logs, not dates claimed for every design rule.
