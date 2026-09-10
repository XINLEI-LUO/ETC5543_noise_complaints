# CLUE Business Feature Dictionary

## Scope

Source: `data/raw/business-establishments-with-address-and-industry-classification.csv`. Period: Census year 2024. Generation script: `analysis/prepare_clue_business_features.R`. Unit: one `device_id + buffer_m` row. The 500 m buffer is primary; 250 m and 1,000 m are sensitivity distances.

| Variable | Definition | Role and limitations |
|---|---|---|
| `device_id` | Validated noise-sensor identifier | Primary join key with `buffer_m` |
| `buffer_m` | Circular buffer radius in metres: 250, 500 or 1,000 | 500 m primary |
| `total_records` | All CLUE records in the buffer, including vacant spaces | Descriptive denominator |
| `total_active_businesses` | Records not coded 0 or described as `Vacant Space` | Primary overall activity measure; records are not guaranteed unique corporate entities |
| `vacant_spaces` | Code 0 or description `Vacant Space` | Secondary urban-context measure |
| `cafes_restaurants` | ANZSIC4 4511 | Primary food-service measure |
| `takeaway_food` | ANZSIC4 4512 | Primary food-service measure |
| `pubs_bars_clue` | ANZSIC4 4520 | QA or secondary measure; overlaps with the specialised bar dataset |
| `other_food_beverage` | Codes 4500–4599 excluding 4511, 4512 and 4520 | Secondary hospitality measure |
| `retail_businesses` | ANZSIC division G, divisions 39–43 | Primary land-use component |
| `accommodation_businesses` | ANZSIC4 4400 | Primary visitor-economy component |
| `entertainment_recreation_businesses` | ANZSIC division R, divisions 89–92 | Primary entertainment component |
| `professional_scientific_technical_businesses` | ANZSIC division M, divisions 69–70 | Primary office-oriented component |
| `financial_insurance_businesses` | ANZSIC division K, divisions 62–64 | Secondary office-oriented component |
| `rental_real_estate_businesses` | ANZSIC division L, divisions 66–67 | Secondary office-oriented component |
| `administrative_support_businesses` | ANZSIC division N, divisions 72–73 | Secondary office/service component |
| `buffer_area_km2` | `pi * (buffer_m / 1000)^2` | Nominal circular area; not boundary-clipped |
| `business_density_per_km2` | Active businesses divided by nominal buffer area | Primary intensity measure; sensitive to non-developable area |
| `vacancy_share` | Vacant records divided by all records; zero for an empty buffer | Secondary composition measure |
| `business_mix_entropy` | Shannon entropy across active records assigned to 19 mutually exclusive ANZSIC divisions | Zero for a confirmed zero-business buffer |
| `business_mix_entropy_normalised` | Entropy divided by `log(19)` | Primary diversity measure, bounded from 0 to 1 |
| `zero_business_buffer` | Whether active-business count is zero | Separates a confirmed zero from missing data |
| `low_business_count_flag` | Whether active-business count is below 10 | Flags potentially unstable diversity values |
| `duplicate_treatment` | Whether source rows were retained or candidate duplicates collapsed | Main output retains source rows |
| `feature_data_year` | 2024 | Prevents accidental temporal mixing |
| `feature_source` | Source CSV filename | Provenance |

## ANZSIC divisions used for entropy

The mutually exclusive categories are: A Agriculture Forestry and Fishing (01–05); B Mining (06–10); C Manufacturing (11–25); D Electricity Gas Water and Waste Services (26); E Construction (27–29); F Wholesale Trade (30–38); G Retail Trade (39–43); H Accommodation and Food Services (44–45); I Transport Postal and Warehousing (46–53); J Information Media and Telecommunications (54–60); K Financial and Insurance Services (62–64); L Rental Hiring and Real Estate Services (66–67); M Professional Scientific and Technical Services (69–70); N Administrative and Support Services (72–73); O Public Administration and Safety (75–77); P Education and Training (80–82); Q Health Care and Social Assistance (84–87); R Arts and Recreation Services (89–92); and S Other Services (94–96).

Vacant code 0 is excluded from this classification and entropy calculation.

## Zero and missing-value rules

Zero indicates that the source loaded successfully and no qualifying records were found in the buffer. `NA` is reserved for missing input, invalid coordinates, failed spatial linkage or another unresolved data problem. The script stops rather than converting such failures to zero.
