# Contribution Evidence Register

## Purpose and attribution rules

This register describes the contributions of the three student team members to the final Melbourne Noise project. The team has clarified the name mappings: **Xinlei Luo = Cindy** and **Chen Liu = Catherine**. These are alternative names for the same two people, not additional contributors.

**Contribution statements follow the team's confirmed division of work, not Git author identities or commit counts.** A Git author entry establishes who committed or merged a file; it does not, by itself, establish who collected the data, developed the analysis, created the figure, interpreted the results, reviewed the work or wrote the report. Meeting records and project files provide supporting context, but planned tasks should not be presented as independently verified completed work. The descriptions below are team-provided role allocations; precise file-level authorship and any shared work should be confirmed before submission.

The scope of this register is limited to the three student members and the final Noise analysis. Teaching staff and work outside the final research scope are excluded.

## Agreed division of responsibilities

| Student (name used in report) | Other name used in project | Main responsibility | Contribution to the research workflow |
|---|---|---|---|
| Sandhya Erland Chandrasekar | Sandhya | Data collection, cleaning and classification | Prepared and organised source datasets and relevant urban-activity categories for subsequent analysis. |
| Xinlei Luo | Cindy | Data analysis, initial method selection and visualisation | Selected and implemented analysis approaches, produced Noise and contextual comparisons, and generated figures and other analytical outputs. |
| Chen Liu | Catherine | In-depth examination of results and graphs, interpretation and conclusions | Critically reviewed analytical patterns, considered consistency and limitations, and developed evidence-based interpretations and conclusions. |

## Narrative contribution statements

### Sandhya Erland Chandrasekar — Data collection, cleaning and classification

Sandhya was primarily responsible for collecting, cleaning and classifying data used in the project. This work involved obtaining and organising relevant City of Melbourne urban-activity sources, including CLUE hospitality and business information and pedestrian counting data. Sandhya examined dataset structures, prepared variables and categories relevant to the research questions, and addressed data-format and quality issues as part of preparing inputs for integration. The hospitality-related preparation included distinguishing venue types and assembling features that could be compared with monitored Noise locations. These tasks provided a clearer, more consistent data foundation for subsequent analysis. Related urban-activity exploration files, data dictionaries and feature outputs may be retained as supporting artefacts, but their presence in Git does not prove sole authorship of all later integrated variables.

### Xinlei Luo (Cindy) — Data analysis, initial method selection and visualisation

Xinlei was primarily responsible for analysing the prepared data, making the initial selection of suitable methods and creating visualisations. The analytical work covered time-of-day and seasonal Noise patterns, differences across monitoring sites, data coverage, and exploratory comparisons with nearby urban activities. Methods considered and applied in the project included median-based summaries, pooled and equal-sensor comparisons, spatial buffer integration and sensitivity checks. Xinlei also worked on sensor-level Noise outcomes, spatial data transformation and integration, analytical validation, and production of graphs and curated results. This work connected the prepared sources with the project's research questions and made results easier to inspect and reproduce. Repository commits under Xinlei's identity are supporting evidence of repository integration and maintenance, not automatic evidence that Xinlei originally authored every committed or merged file.

### Chen Liu (Catherine) — In-depth result review, interpretation and conclusions

Chen was primarily responsible for examining the analytical findings and graphics in greater depth, interpreting their meaning and drawing the project's conclusions. This included reviewing daily and seasonal patterns, differences between monitored locations, and the results of pedestrian and hospitality comparisons. Chen assessed whether reported relationships were consistent across analyses and what the small network, incomplete coverage, overlapping buffers and other limitations meant for the strength of the conclusions. The interpretation work emphasised separating observed associations from causal claims and explaining what the results could and could not support. Project meeting records also associate Chen with spatial checks, map validation and methods discussion, but these records do not independently confirm the completion or sole authorship of every related file. The primary contribution described here is critical interpretation and synthesis of the results into cautious, evidence-based conclusions.

## Supporting records and their limits

| Evidence source | What it can support | What it cannot establish alone |
|---|---|---|
| Team-confirmed role allocation used for this revision | The agreed main division: Sandhya—data preparation; Xinlei—analysis, method choice and figures; Chen—interpretation and conclusions | Exact individual authorship of each line of code, figure or paragraph |
| Meeting agendas and weekly reports | Reported responsibilities, discussion topics, checks and planned tasks | That every planned task was completed, or completed exclusively by the named person |
| Git history and commit metadata | When files were committed or merged and which account recorded the commit | Original authorship, intellectual contribution, review, validation or proportional effort |
| Scripts, data files, figures and saved outputs | What analytical work and deliverables are present in the project | Who originally produced each deliverable without independent confirmation |

Examples of relevant project artefacts to cross-check when assigning exact ownership include `analysis/urban_activity_eda.R`, `analysis/urban_activity_summary.md`, `analysis/noise_eda.R`, `analysis/prepare_noise_outcomes.R`, `analysis/build_sensor_integration.R`, `analysis/validate_sensor_integration.R`, and `analysis/part3_spatial_integration.R`. This is an indicative list from retained records, **not an assignment of exclusive authorship**.

## Team collaboration and verification before submission

The three roles formed a connected process: Sandhya prepared and classified relevant inputs; Xinlei selected methods, analysed the data and visualised results; Chen examined the findings and developed interpretations and conclusions. Work that involved joint decisions, merging, cross-checking or revision should be acknowledged as collaborative where appropriate.