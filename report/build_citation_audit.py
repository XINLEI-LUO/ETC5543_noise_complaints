from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Inches, Pt, RGBColor


OUTPUT = r"report/report_citation_audit.docx"

NAVY = "16324F"
TEAL = "168A86"
PALE = "EAF3F4"
MID = "D7E3E8"
GREY = "5B6670"
BLACK = "111111"
WHITE = "FFFFFF"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=90, start=120, bottom=90, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for name, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{name}"))
        if node is None:
            node = OxmlElement(f"w:{name}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def set_cell_text(cell, text, bold=False, color=BLACK, size=8.5):
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    r = p.add_run(text)
    r.bold = bold
    r.font.name = "Aptos"
    r.font.size = Pt(size)
    r.font.color.rgb = RGBColor.from_string(color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    set_cell_margins(cell)


def add_field_table(doc, rows):
    table = doc.add_table(rows=len(rows), cols=2)
    table.autofit = False
    table.columns[0].width = Cm(3.6)
    table.columns[1].width = Cm(13.4)
    for idx, (label, value) in enumerate(rows):
        left, right = table.rows[idx].cells
        set_cell_shading(left, PALE)
        set_cell_text(left, label, bold=True, color=NAVY, size=8.5)
        set_cell_text(right, value, size=8.5)
    table.style = "Table Grid"
    return table


def add_labelled_paragraph(doc, label, text, quote=False):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_together = True
    label_run = p.add_run(label + " ")
    label_run.bold = True
    label_run.font.color.rgb = RGBColor.from_string(NAVY)
    body = p.add_run(text)
    body.italic = quote
    return p


def add_page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run("Page ")
    run.font.size = Pt(8)
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = "PAGE"
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.append(fld_char1)
    run._r.append(instr_text)
    run._r.append(fld_char2)


records = [
    {
        "id": "A01", "citation": "City of Melbourne (n.d.-a)",
        "reference": "City of Melbourne. (n.d.-a). Microclimate sensors data. Retrieved October 19, 2026, from https://data.melbourne.vic.gov.au/explore/dataset/microclimate-sensors-data/information/",
        "type": "Official government dataset page", "url": "https://data.melbourne.vic.gov.au/explore/dataset/microclimate-sensors-data/information/",
        "report": "Section 1.1 Background and motivation; final PDF p. 2; first paragraph after heading.",
        "claim": "The City of Melbourne describes its microclimate data as readings from sensors located within the city, updated at approximately fifteen-minute intervals, while warning that some intervals may have no readings.",
        "source_location": "Dataset information page, Description/Overview; no fixed page number.",
        "support": "The official page describes the sensor readings, approximate update interval and possible missing intervals. The report uses those statements only to motivate temporal and coverage analysis.",
        "status": "Verified against the official dataset page on 19 October 2026.",
        "limits": "The page does not establish a Noise unit, acoustic calibration or fitness for regulatory exposure interpretation."
    },
    {
        "id": "A02", "citation": "City of Melbourne (2021)",
        "reference": "City of Melbourne. (2021). Microclimate sensor readings data dictionary. https://data.melbourne.vic.gov.au/api/datasets/1.0/microclimate-sensor-readings/attachments/microclimatesensors_metadata_attachment_datadictionary_1_pdf/",
        "type": "Official government data dictionary (PDF)", "url": "https://data.melbourne.vic.gov.au/api/datasets/1.0/microclimate-sensor-readings/attachments/microclimatesensors_metadata_attachment_datadictionary_1_pdf/",
        "report": "Section 1.1 Background and motivation; final PDF p. 2; first paragraph after citation A01.",
        "claim": "An older official data dictionary documents units and expected ranges for temperature, humidity, pressure, particulate matter and wind, but it does not include the Noise field found in the retained project snapshot.",
        "source_location": "PDF pp. 2–3, variable definition tables.",
        "support": "The dictionary lists the documented climate and particulate variables and their units/ranges; a Noise field is absent from the complete variable tables. This supports the report's limited negative claim about that dictionary.",
        "status": "Full three-page PDF inspected; verified.",
        "limits": "Absence from this older dictionary does not prove that no later or internal metadata exists. It establishes only that the available official dictionary does not document the retained field."
    },
    {
        "id": "A03", "citation": "World Health Organization (2018)",
        "reference": "World Health Organization. (2018). Environmental noise guidelines for the European Region. WHO Regional Office for Europe. https://www.who.int/publications/i/item/9789289053563",
        "type": "International public-health guideline", "url": "https://www.who.int/publications/i/item/9789289053563",
        "report": "Section 1.1 Background and motivation; final PDF p. 3; second paragraph.",
        "claim": "The World Health Organization has shown why properly defined environmental-noise exposure matters for health policy, but its recommendations apply to specified noise sources and exposure metrics, not to an undocumented field that merely has a similar numerical range.",
        "source_location": "Official publication landing page, Overview and publication scope; guideline organised by defined environmental-noise sources and exposure indicators.",
        "support": "The guideline is an authoritative source for the health-policy importance of environmental noise and for source- and metric-specific recommendations. The report explicitly refuses to transfer those thresholds to the undocumented project field.",
        "status": "Official publication metadata and overview verified.",
        "limits": "The report does not reproduce or apply any WHO threshold. This citation provides context, not measurement validation."
    },
    {
        "id": "A04", "citation": "Picaut et al. (2020)",
        "reference": "Picaut, J., Can, A., Fortin, N., Ardouin, J., & Lagrange, M. (2020). Low-cost sensors for urban noise monitoring networks: A literature review. Sensors, 20(8), Article 2256. https://doi.org/10.3390/s20082256",
        "type": "Peer-reviewed review article", "url": "https://doi.org/10.3390/s20082256",
        "report": "Section 1.1 Background and motivation; final PDF p. 3; third paragraph.",
        "claim": "Low-cost acoustic sensor networks can increase spatial and temporal coverage, but their usefulness depends on microphone performance, calibration, processing, maintenance, communications and environmental resilience.",
        "source_location": "Abstract and Sections 1–2.3, which review network purposes, sensor architecture, acoustic components, calibration and deployment constraints.",
        "support": "The review discusses both the coverage advantages of low-cost networks and the technical factors that condition data quality and comparability. The report paraphrases that design-level conclusion.",
        "status": "Article metadata, abstract and relevant full-text sections verified.",
        "limits": "The review does not validate the City of Melbourne devices or identify the project's undocumented Noise field."
    },
    {
        "id": "A05", "citation": "Aletta et al. (2016)",
        "reference": "Aletta, F., Kang, J., & Axelsson, Ö. (2016). Soundscape descriptors and a conceptual framework for developing predictive soundscape models. Landscape and Urban Planning, 149, 65–74. https://doi.org/10.1016/j.landurbplan.2016.02.001",
        "type": "Peer-reviewed journal article", "url": "https://doi.org/10.1016/j.landurbplan.2016.02.001",
        "report": "Section 1.1 Background and motivation; final PDF p. 3; fourth paragraph.",
        "claim": "Soundscape research likewise distinguishes physical acoustic conditions from the way people perceive and evaluate an environment.",
        "source_location": "Abstract and conceptual framework sections describing perceptual soundscape dimensions and their relation to acoustic/environmental factors.",
        "support": "The article develops a framework for modelling soundscape descriptors rather than treating physical measurements as direct equivalents of perceptual evaluation. This supports the report's measurement-versus-experience distinction.",
        "status": "Bibliographic record and abstract/conceptual scope verified.",
        "limits": "The project contains no perception survey, so the citation supports a conceptual boundary rather than an empirical claim about Melbourne participants."
    },
    {
        "id": "A06", "citation": "City of Melbourne (n.d.-a)",
        "reference": "City of Melbourne. (n.d.-a). Microclimate sensors data. Retrieved October 19, 2026, from https://data.melbourne.vic.gov.au/explore/dataset/microclimate-sensors-data/information/",
        "type": "Official government dataset page", "url": "https://data.melbourne.vic.gov.au/explore/dataset/microclimate-sensors-data/information/",
        "report": "Section 2.1.a Microclimate sensor snapshot; final PDF p. 4; first paragraph.",
        "claim": "The official portal describes the dataset as approximately fifteen-minute climate readings and notes that readings may be absent for some intervals.",
        "source_location": "Dataset information page, Description/Overview; no fixed page number.",
        "support": "The cited page directly describes the update cadence and possibility of gaps. These statements justify inspecting observed intervals and completeness rather than assuming a perfect schedule.",
        "status": "Verified against the official dataset page.",
        "limits": "The page describes the live dataset generally; the report's exact row counts and dates come from the checksummed retained snapshot, not from the webpage."
    },
    {
        "id": "A07", "citation": "City of Melbourne (n.d.-b)",
        "reference": "City of Melbourne. (n.d.-b). Microclimate sensor locations historical. Retrieved October 19, 2026, from https://data.melbourne.vic.gov.au/explore/dataset/microclimate-sensor-locations/information/",
        "type": "Official government dataset page", "url": "https://data.melbourne.vic.gov.au/explore/dataset/microclimate-sensor-locations/information/",
        "report": "Section 2.1.a Microclimate sensor snapshot; final PDF p. 4; third paragraph.",
        "claim": "Historical sensor-location metadata warns that devices may be relocated and that location changes matter when interpreting historical observations.",
        "source_location": "Dataset description and historical-location fields; no fixed page number.",
        "support": "The historical locations dataset records sensor siting through time and makes relocation relevant to longitudinal interpretation. The report converts this into a conservative installation-history caveat.",
        "status": "Official metadata page verified.",
        "limits": "The cited page does not provide a complete device-history match for every identifier in the retained snapshot."
    },
    {
        "id": "A08", "citation": "City of Melbourne (n.d.-c)",
        "reference": "City of Melbourne. (n.d.-c). Pedestrian Counting System counts per hour. Retrieved October 19, 2026, from https://data.melbourne.vic.gov.au/explore/dataset/pedestrian-counting-system-monthly-counts-per-hour/information/",
        "type": "Official government dataset page", "url": "https://data.melbourne.vic.gov.au/explore/dataset/pedestrian-counting-system-monthly-counts-per-hour/information/",
        "report": "Section 2.1.b Pedestrian activity data; final PDF p. 5; first paragraph.",
        "claim": "The City portal defines each row as an hourly pedestrian count and states that the location key should be joined to the sensor-location dataset; it also warns that location changes affect interpretation through time.",
        "source_location": "Dataset Description and field/join information; no fixed page number.",
        "support": "The page identifies the hourly count unit and the relationship to sensor-location metadata. This supports the project's join design and temporal-location caution.",
        "status": "Official dataset page verified.",
        "limits": "The report's 2024–2026 retained coverage is an inspection result from the local file, not a claim taken from the current webpage."
    },
    {
        "id": "A09", "citation": "City of Melbourne (n.d.-d)",
        "reference": "City of Melbourne. (n.d.-d). Pedestrian Counting System sensor locations. Retrieved October 19, 2026, from https://data.melbourne.vic.gov.au/explore/dataset/pedestrian-counting-system-sensor-locations/information/",
        "type": "Official government dataset page", "url": "https://data.melbourne.vic.gov.au/explore/dataset/pedestrian-counting-system-sensor-locations/information/",
        "report": "Section 2.1.b Pedestrian activity data; final PDF p. 5; first paragraph.",
        "claim": "The location metadata explains that the system records movements through counting zones rather than images or unique individuals.",
        "source_location": "Dataset Description/Privacy and sensor-operation explanation; no fixed page number.",
        "support": "The official description characterises the counters as movement-counting devices and distinguishes their output from images or unique-person identification. The report therefore labels observations as movements.",
        "status": "Official metadata page verified.",
        "limits": "A movement count cannot be converted into unique visitors without additional tracking assumptions, which the report does not make."
    },
    {
        "id": "A10", "citation": "City of Melbourne (n.d.-e)",
        "reference": "City of Melbourne. (n.d.-e). Business establishments location and industry classification. Retrieved October 19, 2026, from https://data.melbourne.vic.gov.au/explore/dataset/business-establishments-with-address-and-industry-classification/information/",
        "type": "Official government dataset page", "url": "https://data.melbourne.vic.gov.au/explore/dataset/business-establishments-with-address-and-industry-classification/information/",
        "report": "Section 2.1.c Hospitality and business context; final PDF p. 5; first paragraph.",
        "claim": "The City explains that CLUE establishment counts represent business locations rather than unique enterprises, because the same organisation can be counted at multiple premises.",
        "source_location": "Dataset Description, unit-of-count explanation; no fixed page number.",
        "support": "The official page defines establishments at location level and cautions that an organisation with several locations can appear several times. The report uses the same unit language.",
        "status": "Official dataset page verified.",
        "limits": "The cited definition does not indicate visits, trading status at a specific hour or corporate ownership counts."
    },
    {
        "id": "A11", "citation": "City of Melbourne (n.d.-f)",
        "reference": "City of Melbourne. (n.d.-f). Cafe restaurant bistro seats. Retrieved October 19, 2026, from https://data.melbourne.vic.gov.au/explore/dataset/cafes-and-restaurants-with-seating-capacity/information/",
        "type": "Official government dataset page", "url": "https://data.melbourne.vic.gov.au/explore/dataset/cafes-and-restaurants-with-seating-capacity/information/",
        "report": "Section 2.1.c Hospitality and business context; final PDF p. 5; second paragraph.",
        "claim": "City metadata describes the cafe data as CLUE records with trading name, address, ANZSIC classification, seating type and seats.",
        "source_location": "Dataset Description and field list; no fixed page number.",
        "support": "The official metadata identifies the venue, address, industry and seating attributes used to characterise the source. The report does not infer more detailed behaviour from them.",
        "status": "Official dataset page verified.",
        "limits": "Recorded capacity or seats are not realised attendance, opening hours or time-aligned exposure."
    },
    {
        "id": "A12", "citation": "Pebesma (2018)",
        "reference": "Pebesma, E. (2018). Simple features for R: Standardized support for spatial vector data. The R Journal, 10(1), 439–446. https://doi.org/10.32614/RJ-2018-009",
        "type": "Peer-reviewed software/method article", "url": "https://doi.org/10.32614/RJ-2018-009",
        "report": "Section 2.1.d Spatial reference data; final PDF p. 5; only paragraph.",
        "claim": "The sf package implements standard simple-feature geometry and connects R to established spatial libraries for reading, transformation and geometric operations.",
        "source_location": "Article pp. 439–446, especially package architecture and geometry-operation discussion on pp. 440–443.",
        "support": "The article documents the R simple-features implementation and its links to GDAL, GEOS and PROJ functionality. This supports the software-method description.",
        "status": "Article and bibliographic details verified.",
        "limits": "The citation supports the toolchain, not the substantive appropriateness of every project buffer choice; that choice is justified separately."
    },
    {
        "id": "A13", "citation": "Wickham (2016)",
        "reference": "Wickham, H. (2016). ggplot2: Elegant graphics for data analysis. Springer. https://doi.org/10.1007/978-3-319-24277-4",
        "type": "Scholarly software-method book", "url": "https://doi.org/10.1007/978-3-319-24277-4",
        "report": "Section 3.1 Analysis principles; final PDF p. 7; second paragraph.",
        "claim": "Graphical output follows the layered grammar implemented in ggplot2 where R is used.",
        "source_location": "Book overview and Chapter 1, which introduce ggplot2 and its layered grammar of graphics.",
        "support": "The book is the authoritative methodological reference for ggplot2's layered grammar. The report uses it only to identify the visualisation framework.",
        "status": "Publisher metadata, DOI and methodological scope verified.",
        "limits": "This citation does not validate the project's individual aesthetic choices or numerical calculations."
    },
    {
        "id": "A14", "citation": "Picaut et al. (2020)",
        "reference": "Picaut, J., Can, A., Fortin, N., Ardouin, J., & Lagrange, M. (2020). Low-cost sensors for urban noise monitoring networks: A literature review. Sensors, 20(8), Article 2256. https://doi.org/10.3390/s20082256",
        "type": "Peer-reviewed review article", "url": "https://doi.org/10.3390/s20082256",
        "report": "Section 5.3 Measurement interpretation; final PDF p. 19; third paragraph.",
        "claim": "Picaut et al. (2020) describe acoustic performance, calibration, microphone choice and environmental robustness as essential design considerations.",
        "source_location": "Sections 2.2–2.3 on hardware/acoustic performance, sensor design and calibration/deployment constraints.",
        "support": "The review directly treats these technical characteristics as determinants of measurement performance and network reliability. The report applies the lesson as a reason for cautious interpretation.",
        "status": "Relevant full-text sections verified.",
        "limits": "The source offers general design evidence; the City deployment's actual hardware and calibration remain unknown."
    },
    {
        "id": "A15", "citation": "Picaut et al. (2020)",
        "reference": "Picaut, J., Can, A., Fortin, N., Ardouin, J., & Lagrange, M. (2020). Low-cost sensors for urban noise monitoring networks: A literature review. Sensors, 20(8), Article 2256. https://doi.org/10.3390/s20082256",
        "type": "Peer-reviewed review article", "url": "https://doi.org/10.3390/s20082256",
        "report": "Section 5.5 Spatial scale and dependence; final PDF p. 19; third paragraph.",
        "claim": "Low-cost monitoring research often aims to increase network density precisely because sound environments vary over space and time.",
        "source_location": "Abstract and Introduction, which motivate dense distributed networks for spatial and temporal urban-noise characterisation.",
        "support": "The review frames low-cost networks as a response to the limits of sparse conventional monitoring and the need for broader spatiotemporal coverage.",
        "status": "Article abstract and introduction verified.",
        "limits": "The source does not imply that sparse points may be interpolated safely; the report reaches the opposite, conservative project-specific conclusion."
    },
    {
        "id": "A16", "citation": "Brown and Muhar (2004)",
        "reference": "Brown, A. L., & Muhar, A. (2004). An approach to the acoustic design of outdoor space. Journal of Environmental Planning and Management, 47(6), 827–842. https://doi.org/10.1080/0964056042000284857",
        "type": "Peer-reviewed journal article", "url": "https://doi.org/10.1080/0964056042000284857",
        "report": "Section 5.10 Future research; final PDF p. 22; first paragraph before the Conclusion heading.",
        "claim": "Soundscape planning research emphasises the role of perception and context in evaluating outdoor spaces.",
        "source_location": "Abstract and pp. 827–829, where acoustic design is framed through users, activities, environmental context and perception.",
        "support": "The paper argues for an outdoor acoustic-design approach that goes beyond a single physical level and considers people, activities and context. This supports the proposed addition of surveys or soundwalks.",
        "status": "Article metadata and abstract/introductory argument verified.",
        "limits": "The paper supports a future-research recommendation; it supplies no direct observation about the monitored Melbourne sites."
    },
]

verification_categories = {
    "A01": "Official page verified",
    "A02": "Full text verified",
    "A03": "Metadata/overview verified",
    "A04": "Full text verified",
    "A05": "Abstract/concept verified",
    "A06": "Official page verified",
    "A07": "Official page verified",
    "A08": "Official page verified",
    "A09": "Official page verified",
    "A10": "Official page verified",
    "A11": "Official page verified",
    "A12": "Full text verified",
    "A13": "Publisher metadata verified",
    "A14": "Full text verified",
    "A15": "Full text verified",
    "A16": "Abstract/intro verified",
}
for record in records:
    record["verification_category"] = verification_categories[record["id"]]


doc = Document()
doc.settings.odd_and_even_pages_header_footer = False
sec = doc.sections[0]
sec.page_width = Cm(21.0)
sec.page_height = Cm(29.7)
sec.top_margin = Cm(1.6)
sec.bottom_margin = Cm(1.5)
sec.left_margin = Cm(1.8)
sec.right_margin = Cm(1.8)

styles = doc.styles
normal = styles["Normal"]
normal.font.name = "Aptos"
normal.font.size = Pt(9.2)
normal.font.color.rgb = RGBColor.from_string(BLACK)
normal.paragraph_format.space_after = Pt(4)
normal.paragraph_format.line_spacing = 1.06

for style_name, size, colour in (("Title", 26, NAVY), ("Subtitle", 12, GREY), ("Heading 1", 16, NAVY), ("Heading 2", 12, TEAL)):
    style = styles[style_name]
    style.font.name = "Aptos Display" if "Heading" in style_name or style_name == "Title" else "Aptos"
    style.font.size = Pt(size)
    style.font.color.rgb = RGBColor.from_string(colour)
    style.font.bold = style_name != "Subtitle"

styles["Heading 1"].paragraph_format.space_before = Pt(10)
styles["Heading 1"].paragraph_format.space_after = Pt(5)
styles["Heading 1"].paragraph_format.keep_with_next = True
styles["Heading 2"].paragraph_format.space_before = Pt(7)
styles["Heading 2"].paragraph_format.space_after = Pt(4)
styles["Heading 2"].paragraph_format.keep_with_next = True

small = styles.add_style("Audit Small", WD_STYLE_TYPE.PARAGRAPH)
small.font.name = "Aptos"
small.font.size = Pt(8)
small.font.color.rgb = RGBColor.from_string(GREY)
small.paragraph_format.space_after = Pt(2)

header = sec.header.paragraphs[0]
header.text = "ETC5543 FINAL REPORT  •  CITATION AUDIT"
header.alignment = WD_ALIGN_PARAGRAPH.LEFT
for run in header.runs:
    run.font.name = "Aptos"
    run.font.size = Pt(8)
    run.font.bold = True
    run.font.color.rgb = RGBColor.from_string(TEAL)

footer = sec.footer.paragraphs[0]
add_page_number(footer)

title = doc.add_paragraph(style="Title")
title.alignment = WD_ALIGN_PARAGRAPH.LEFT
title.add_run("Citation Audit")
sub = doc.add_paragraph(style="Subtitle")
sub.add_run("Recorded Noise Patterns at Monitored Melbourne Locations")

rule = doc.add_paragraph()
rule.paragraph_format.space_before = Pt(3)
rule.paragraph_format.space_after = Pt(12)
run = rule.add_run("VERIFIED SOURCE-TO-CLAIM REGISTER")
run.bold = True
run.font.size = Pt(9)
run.font.color.rgb = RGBColor.from_string(WHITE)
rule.paragraph_format.shading = None
p_pr = rule._p.get_or_add_pPr()
shd = OxmlElement("w:shd")
shd.set(qn("w:fill"), NAVY)
p_pr.append(shd)
ind = OxmlElement("w:ind")
ind.set(qn("w:left"), "160")
ind.set(qn("w:right"), "160")
p_pr.append(ind)

doc.add_paragraph(
    "This audit covers every author–date citation occurrence in the final report body. It records the exact report claim, final PDF location, original-source location, support assessment, verification status and interpretive boundary. Project-data claims are audited separately in report_source_traceability.md."
)

summary = doc.add_table(rows=2, cols=4)
summary.autofit = False
summary_data = (("16", "in-text occurrences"), ("13", "unique sources"), ("24", "final PDF pages"), ("28 Oct 2026", "audit date"))
for col, (value, label) in enumerate(summary_data):
    top = summary.cell(0, col)
    bottom = summary.cell(1, col)
    set_cell_shading(top, NAVY)
    set_cell_shading(bottom, PALE)
    set_cell_text(top, value, bold=True, color=WHITE, size=14)
    top.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
    set_cell_text(bottom, label, color=GREY, size=8)
    bottom.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER

doc.add_paragraph()
doc.add_heading("Audit index", level=1)
index = doc.add_table(rows=1, cols=5)
index.style = "Table Grid"
headers = ("ID", "Citation", "Report section", "PDF", "Status")
for c, text in zip(index.rows[0].cells, headers):
    set_cell_shading(c, NAVY)
    set_cell_text(c, text, bold=True, color=WHITE, size=8)
set_repeat_table_header(index.rows[0])

for rec in records:
    section_name = rec["report"].split(";", 1)[0].replace("Section ", "")
    page = rec["report"].split("final PDF p. ", 1)[1].split(";", 1)[0]
    row = index.add_row().cells
    values = (rec["id"], rec["citation"], section_name, page, rec["verification_category"])
    for idx, (cell, value) in enumerate(zip(row, values)):
        if idx == 0:
            set_cell_shading(cell, PALE)
            set_cell_text(cell, value, bold=True, color=TEAL, size=7.7)
        else:
            set_cell_text(cell, value, size=7.7)

doc.add_page_break()
doc.add_heading("Detailed occurrence records", level=1)
intro = doc.add_paragraph(style="Audit Small")
intro.add_run("Verification status refers to the claim as used in the report; it is not a blanket endorsement of every possible inference from the source.")

for idx, rec in enumerate(records):
    if idx:
        new_sec = doc.add_section(WD_SECTION.NEW_PAGE)
        new_sec.page_width = Cm(21.0)
        new_sec.page_height = Cm(29.7)
        new_sec.top_margin = Cm(1.6)
        new_sec.bottom_margin = Cm(1.5)
        new_sec.left_margin = Cm(1.8)
        new_sec.right_margin = Cm(1.8)
        new_sec.header.is_linked_to_previous = True
        new_sec.footer.is_linked_to_previous = True
    heading = doc.add_heading(f"{rec['id']}  {rec['citation']}", level=2)
    heading.paragraph_format.keep_with_next = True
    add_field_table(doc, [
        ("APA reference", rec["reference"]),
        ("Source type", rec["type"]),
        ("DOI / URL", rec["url"]),
        ("Report location", rec["report"]),
        ("Original-source location", rec["source_location"]),
        ("Verification category", rec["verification_category"]),
        ("Verification detail", rec["status"]),
    ])
    add_labelled_paragraph(doc, "Report claim:", rec["claim"], quote=True)
    add_labelled_paragraph(doc, "Support assessment:", rec["support"])
    p = add_labelled_paragraph(doc, "Boundary:", rec["limits"])
    for run in p.runs[1:]:
        run.font.color.rgb = RGBColor.from_string(GREY)

doc.add_page_break()
doc.add_heading("Audit conclusion", level=1)
doc.add_paragraph(
    "All 16 in-text citation occurrences have a matching full reference and a source relevant to the claim as used. Verification depth is not uniform: some sources were inspected in full, while others were checked through official metadata, abstracts or introductory material. The report generally uses external evidence to define datasets, identify analytical tools or set interpretive boundaries. No external source is used to manufacture a project result. The strongest restriction is deliberate: authoritative metadata reviewed for this project does not establish a physical unit or calibration basis for the retained Noise field, so WHO thresholds and decibel terminology are not applied."
)
doc.add_paragraph(
    "Verification depth varies by source format. Official dataset webpages were checked at the page and field-description level; the City data dictionary was inspected in full; peer-reviewed articles were checked at the abstract and relevant-section level; and the ggplot2 book was checked at publisher and methodological-scope level. These limits are stated record by record."
)

doc.core_properties.title = "ETC5543 final report citation audit"
doc.core_properties.subject = "Source-to-claim verification register"
doc.core_properties.author = "Sandhya Erland Chandrasekar; Xinlei Luo; Chen Liu"
doc.core_properties.keywords = "ETC5543, citation audit, APA 7, source verification"
doc.save(OUTPUT)
print(OUTPUT)
