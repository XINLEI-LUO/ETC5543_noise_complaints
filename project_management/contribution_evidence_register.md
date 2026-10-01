# Contribution Evidence Register

## Interpretation rule

Git author names show who committed a change, not necessarily who designed, wrote, reviewed or validated it. Meeting records document intended or reported allocations, but they also contain early and superseded statements. No final contribution claim should be published until each member confirms it.

The repository uses several names that cannot be safely equated from files alone: Cindy, Xinlei, Catherine, Chen Liu, Sandhya and Minh Huynh. In particular, the audit does not assume that Cindy and Xinlei are the same person, or that Catherine and Chen are the same person. These mappings require team confirmation.

## Git-level evidence

`git shortlog -sne --all` reports:

| Git author identity | Commits | What this establishes | What it does not establish |
|---|---:|---|---|
| Xinlei `<xluo0036@student.monash.edu>` | 41 | Most current pipeline, documentation, curated outputs and merges were committed under this identity | Whether Xinlei is Cindy; whether merged files were authored by another member; extent of review |
| Sandhya `<sandhya@CHANDRASEKARs-MacBook-Pro.local>` | 4 | Early urban-activity scripts, dictionaries, cleaned feature outputs and raw dataset additions appear in branch history | Whether all current urban features were solely produced by Sandhya |
| Chen Liu `<cliu0197@student.monash.edu>` | 3 | `analysis/part3_spatial_integration.R` and uploaded files are associated with this identity | Whether later validated spatial scripts were written or reviewed by Chen |
| Minh Huynh `<minh.vq.huynh@gmail.com>` | 1 | Top-level population/biodiversity-related data were added | Whether Minh contributed to the current scoped Noise analysis |

## File and meeting evidence

| Person/name in records | Reported responsibility | Specific evidence | Confidence | Required confirmation |
|---|---|---|---|---|
| Cindy | Noise EDA, sensor outcomes, coverage, spatial transformation, buffers, integration and validation outputs | `meetings/Catherine_weekly_report.docx` assigns Noise work to Cindy; 4 September agenda assigns Cindy the outcomes, buffers, integration and duplicate checks; files include `analysis/noise_eda.R`, `analysis/prepare_noise_outcomes.R`, `analysis/build_sensor_integration.R`, `analysis/validate_sensor_integration.R` and related outputs | Medium | Confirm which exact files Cindy authored, reviewed or validated and whether Cindy maps to a Git identity |
| Sandhya | Urban activity/nightlife features, bars/pubs, capacity, seating and pedestrian feasibility | Weekly report and 4 September agenda; Git commits `410ab0c`, `75e999b`, `13c665d`, `7965e01`; current related sources include `analysis/urban_activity_eda.R`, `analysis/urban_activity_summary.md`, raw CLUE/pedestrian files | High for early work; medium for current integrated outputs | Confirm contribution to current multiyear pedestrian integration and current CLUE feature specification |
| Chen | Spatial integration, manual sensor checks, map validation and methods documentation | 4 September agenda reports manual validation and a methods note; Git author Chen Liu committed `analysis/part3_spatial_integration.R` | Medium | Confirm whether Chen completed the manual checks/method note and reviewed the later validated map/pipeline |
| Xinlei | Repository integration, current reproducibility pipeline and many current commits | Git history associates Xinlei with current R/Python pipeline, curated outputs, CLUE extension, README and reproducibility records | High for commit/integration activity | Confirm personal identity and distinguish original authorship from branch merges and maintenance |
| Catherine | Named in `meetings/Catherine_weekly_report.docx`; 21 August agenda assigns population/built-environment/data integration to Catherine | Document naming and agenda text | Low | Confirm whether Catherine is a team member, whether this maps to Chen or another person, and whether planned work was completed |
| Minh Huynh | Added population/biodiversity-related datasets | Git commit `95ecafd` | High for the commit; low for current-scope contribution | Confirm whether this work should appear in the final contribution table after population/biodiversity left the scope |

## Proposed final contribution table pending confirmation

| Member | Main responsibility | Specific files or analyses | Final presentation contribution | Validation or review contribution | Status |
|---|---|---|---|---|---|
| Cindy | Noise temporal and sensor-level analysis | Confirm exact ownership of `analysis/noise_eda.R`, `analysis/prepare_noise_outcomes.R`, sensor coverage, hourly/weekday/seasonal outputs and new sensor-by-time figures | Temporal and sensor-by-time sections | Confirm checks of coverage, zero and duplicate sensitivity | Requires team confirmation |
| Sandhya | Urban activity and amenity context | Early urban activity scripts/data; confirm ownership of current CLUE and pedestrian feature definitions | Data sources and descriptive location profiles | Confirm feature QA and interpretation review | Requires team confirmation |
| Chen | Spatial integration and validation | `analysis/part3_spatial_integration.R`; confirm later map/method review | Spatial design and revised 500 m map | Confirm manual selected-sensor checks and map validation | Requires team confirmation |
| Other confirmed member(s) | To be specified | Population/built environment or repository integration only if relevant to final scope | To be specified | To be specified | Requires identity and scope confirmation |

## Confirmation questions for the team

1. Is Xinlei the same person as Cindy? If yes, use one consistent final name.
2. Is Catherine the same person as Chen, a different member, or an outdated agenda label?
3. Which member authored versus merged each of the current pipeline scripts?
4. Did Chen complete the stated manual checks and methods note, and where are those records?
5. Did Sandhya contribute to the current 2025 pedestrian integration/statistics or only the earlier data preparation?
6. Should Minh's out-of-scope population/biodiversity data contribution appear in the final table?
7. Who will own the new sensor-by-time figures, revised map, RQ3 profile, HTML assembly and independent QA?

## Evidence to retain for submission

- A reviewed final contribution table signed off in team communication.
- Git revision used for the HTML.
- Exact files/analyses listed per member.
- Separate entries for presentation writing and for validation/review, not just code commits.
- A note where work was collaborative or merged from a branch.

