# SPEC — Maintenance Project Planner

เอกสาร technical specification ของแอป **Maintenance Project Planner** สำหรับผู้ที่ต้องการเข้าใจโครงสร้างและ
การทำงานของแอปโดยไม่ต้องไล่อ่านโค้ดทั้งไฟล์

## 1. ภาพรวมโปรเจกต์

- **ชื่อแอป**: Maintenance Project Planner (Gantt chart planner สำหรับงาน maintenance/factory project)
- **วัตถุประสงค์**: วางแผนและติดตามโครงการซ่อมบำรุง/โครงการโรงงาน ด้วย Gantt chart ที่รองรับ dependency,
  critical path, S-Curve และ dashboard สรุปภาพรวม
- **Deploy**: https://maintenance-project-planner.vercel.app/ (Vercel, auto-deploy จาก branch `main`)
- **Tech stack**: static single-file app — ไฟล์เดียว `index.html` รวม HTML + CSS + JavaScript ทั้งหมด
  - Vanilla JavaScript ล้วน ไม่มี framework (ไม่มี React/Vue/jQuery)
  - ไม่มี build step, ไม่มี npm/package.json — แก้ไฟล์แล้วเปิดในเบราว์เซอร์ได้ทันที
  - ภาษา UI หลัก: ไทย (`lang="th"`)

## 2. สถาปัตยกรรมไฟล์ (โครงสร้าง DOM หลักใน `index.html`)

```
<body>
  .login-overlay#loginOverlay          ← ด่าน Google Sign-In (บังคับ login ก่อนเข้าแอป)
  .app-container#appContainer
    header.app-bar                     ← toolbar บน (ชื่อโครงการ, zoom, ช่วงวันที่, ปุ่ม action)
    .drawer-overlay + .drawer-menu#drawerMenu   ← เมนู hamburger (☰)
    .help-overlay + .help-panel#helpPanel       ← คู่มือผู้ใช้ (เลื่อนเข้าจากขวา)
    .cp-info-banner#cpInfoBanner        ← แบนเนอร์สรุป Critical Path
    .compare-info-banner#compareInfoBanner      ← แบนเนอร์โหมดเทียบ Baseline
    .main-split (CSS grid 2 แถว)
      .nav-rail#navRail                 ← rail ไอคอนซ้ายสุด สลับ 5 view: Timeline(gantt)/Progress(dashboard)/
                                            Baseline/Calendar/Config (Config เปิด modal ไม่ใช่สลับ view)
      .task-sidebar#taskSidebar → .task-tree-container#taskTreeContainer  ← ต้นไม้ Task ฝั่งซ้าย
      .timeline-wrapper#timelineWrapper
        .timeline-header-clip → .timeline-header-sticky   ← หัวตารางวันที่ (fixed, ไม่ scroll เอง)
        .timeline-scroll-body#timelineScrollBody → .timeline-body-area#timelineBodyArea + <svg#dependencySvg>
      .scurve-row-spacer#scurveRowSpacer + .scurve-clip#scurveClip → #scurveContainer   ← แผง S-Curve
      .dashboard-view#dashboardView     ← หน้า Progress/Dashboard (ซ่อนเมื่อไม่ได้เลือก)
      .dashboard-view#baselineView      ← หน้า Baseline History & Comparison แบบเต็มหน้า (reuse class เดียวกัน)
      .dashboard-view#calendarView      ← หน้า Working Calendar & Shift Schedule แบบเต็มหน้า (reuse class เดียวกัน)
  Modals (.modal-backdrop, เปิด/ปิดด้วย class .open):
    #timescaleModal      — ตั้งค่าระดับเวลาที่แสดงบนหัวตาราง
    #taskModal           — แก้ไข Task
    #calendarModal       — ตั้งเวลาทำงาน/วันหยุดรายสัปดาห์ (ควบคุมโดยหน้า Calendar ผ่านปุ่ม "Edit Working
                            Hours & Weekdays" แทนที่จะเปิดจาก nav-rail โดยตรงแล้ว)
    #projectSafetyModal  — แก้ไข Buffer Days / Lost Time Incidents / Man-Hours Logged / Shift Crews
    #configModal         — System & Project Configuration (4 แท็บ ดูหัวข้อ 3)
    #mhModal             — จัดการ Marks & Highlights
    #historyModal        — Baseline History แบบ modal ย่อ (quick-access เดิม, ยังอยู่คู่กับหน้า Baseline เต็ม)
  <input type="file" id="fileImportInput" hidden>   ← ใช้ import JSON
```

### ธีม
UI ปัจจุบันเป็นธีมมืด "dark industrial" ทั้งหมด ไม่ใช่ system font stack แบบเรียบง่ายอีกต่อไป — ใช้ CSS
custom properties ขึ้นต้นด้วย `--dt-*` (เช่น `--dt-surface-base`, `--dt-surface-panel`,
`--dt-critical-path`, `--dt-scurve-actual`/`--dt-scurve-planned`, `--dt-baseline-purple`,
`--dt-warning-amber`, `--dt-border-subtle`, `--dt-text-primary`/`--dt-text-secondary`/`--dt-text-muted`)
และฟอนต์ที่โหลดจาก Google Fonts CDN: `--font-sans` (Be Vietnam Pro), `--font-mono` (JetBrains Mono),
`--font-headline` (Space Grotesk)

โครงสร้าง `.main-split` เป็น **CSS Grid 2 แถว** (แถวบน = nav-rail/sidebar/timeline, แถวล่าง = S-Curve) เพื่อให้
ทุกคอลัมน์แถวบนหด/ขยายความสูงเท่ากันเสมอเมื่อ S-Curve เปิด/ปิด — เป็นจุดสำคัญที่ทำให้ vertical scroll-sync ระหว่าง
task list กับ Gantt bar ตรงกันเป๊ะ (ดูหัวข้อ Storage & Sync/scroll-sync ด้านล่าง)

## 3. ฟีเจอร์ทั้งหมด

- **Task CRUD**: เพิ่ม task หลัก (`+Task`), เพิ่ม sub-task, แก้ไขผ่าน modal (double-click แท่ง/milestone หรือกด
  ไอคอนดินสอ), ลบ (ไอคอนถังขยะใน modal)
- **โครงสร้างลำดับชั้น**: ซ้อนได้ไม่จำกัดชั้นผ่าน `parentId`, ย่อ/ขยาย (collapse/expand), เยื้อง/ลดเยื้อง (⇥/⇤),
  ลาก-วางเพื่อจัดลำดับ/เปลี่ยน parent
- **โหมดความคืบหน้า**: `manual` (กรอกเอง 0–100%) หรือ `auto` (rollup เฉลี่ยจากลูก)
- **ประเภทรายการ**: `task`, `milestone` (สัญลักษณ์เพชร วันเดียว), `mark` (เส้นแนวตั้งระบุวันสำคัญ),
  `highlight` (แถบพื้นหลังช่วงวันที่) — mark/highlight ซ่อนจาก list ซ้ายได้ (`hidden`) แต่ยังโชว์บน Gantt
- **Dependencies & Linking**: ลากเชื่อมจากจุดจับที่ขอบแท่ง/milestone หรือพิมพ์ข้อความ (เช่น `3FS, 5SS`) รองรับ
  FS/SS/FF/SF ครบ มี guard กันวนลูป (`wouldCreateCycle`) คลิกเส้นเชื่อมเพื่อลบได้ (มี confirm)
- **ลาก-ปรับแท่งงาน**: ลากย้ายวันที่, ลากขอบขวาปรับระยะเวลา, milestone ลากได้เฉพาะวันที่ — re-render สดระหว่างลาก
- **Gantt rendering & Zoom**: หัวตารางหลายระดับ (ปี/ไตรมาส/เดือน/สัปดาห์/วัน เปิด-ปิดได้อิสระ), แรเงาวันหยุด,
  เส้น "วันนี้", zoom 4 ระดับ (Day/Week/Month/Quarter)
- **ช่วงวันที่แสดงผล**: กำหนดเองผ่าน input วันที่ หรือ Auto-fit (`autoTimeBounds`) คำนวณจากวันที่ทุก task
- **Critical Path (CPM)**: ปุ่ม `#btnToggleCP` — คำนวณ Forward/Backward pass รองรับ lag ทั้ง 4 แบบ, หา Total
  Float, ไฮไลต์ task ที่ TF≤0 เป็น critical (สีแดง) พร้อมแบนเนอร์สรุประยะเวลา/จำนวน critical task
- **S-Curve**: ปุ่ม `#btnToggleSCurve` — กราฟความคืบหน้าสะสมแบบถ่วงน้ำหนัก (planned vs actual) เลือกวิธีถ่วง
  น้ำหนักได้ผ่าน Config (`systemConfig.progressWeightMethod`: Duration/Man-Hour/Cost-Weighted ใช้
  `getTaskWeight(t)` กลาง) พร้อม Confidence Envelope ±X% รอบเส้น Planned (`systemConfig.scurveConfidencePct`)
  แสดงใต้ Gantt และแสดงซ้ำแบบเต็มใน Dashboard

### Progress (Dashboard) — `renderDashboard()`, nav-rail "📈 Progress"
- **Overall Progress (S-Curve)**: % รวมถ่วงน้ำหนักตาม `getTaskWeight`, กราฟ SVG S-Curve เต็ม (planned vs
  actual, Confidence Envelope, จุด milestone, เส้น "วันนี้")
- **EVM (Earned Value Management)**: `computeEVM()` คำนวณ PV (Planned Value), EV (Earned Value), AC (Actual
  Cost, จาก `task.actualCost`), SPI (Schedule Performance Index), CPI (Cost Performance Index) — แสดง
  Schedule Variance (SV) เป็นทั้งเงินและ % พร้อมเทียบกับ Official Baseline (`systemConfig.officialBaselineId`)
- **Critical Path Status**: จำนวน critical task, Longest path (วัน), **Buffer Depletion**
  (`computeBufferDepletion(cp)` — เทียบ CPM forecast finish กับวันที่วางแผนจริง หารด้วย buffer ที่ตั้งไว้
  `projectSafety.bufferDays`, ไม่ใช่ CCPM เต็มรูปแบบ)
- **WBS Execution Status**: กราฟ stacked bar สถานะ task ทั้งหมด (เสร็จ/ดำเนินการ/รอ)
- **Safety & Effort**: Man-Hours Logged, Lost Time Incidents, Shift Crews (จาก `projectSafety`, แก้ไขผ่าน
  `#projectSafetyModal`)
- **Critical Path Tasks At Risk** และ **Upcoming Milestones & Gate Reviews**: รายการ task/milestone ที่ต้อง
  จับตา
- **Task Distribution & Workload by Team**: การ์ดสรุปงานตาม `task.team` พร้อม % สถานะและจำนวนงานบน critical path

### System & Project Configuration — `openConfigModal()`, nav-rail "⚙️ Config" (modal, ไม่ใช่ full page)
4 แท็บ ทุก control ผูกกับ logic การคำนวณจริง ไม่ใช่แค่เก็บค่าเฉยๆ:
- **ข้อมูลโครงการ & WBS** (`info`): Plant Facility, Outage Code, Target Cold Run Date, Grid Sync COD +
  Planned Duration คำนวณอัตโนมัติจากข้อมูล task จริง
- **CPM Engine & S-Curve Rules** (`cpm`): Progress Weight Method, Critical Float Threshold (≤0/≤1, แทนที่
  hardcoded ใน `computeCriticalPath()`), Dependency Lag Calculation (workdays/calendar), Early/Late Date
  Strategy ("Late Dates Constrained by Target COD"), Instant CPM Recalculate (cache ผลลัพธ์จนกว่าจะกด
  Recalculate), S-Curve Confidence Envelope, และตั้ง **Official Baseline** (`officialBaselineId`) สำหรับใช้
  เทียบใน EVM/Dashboard/Baseline page — dropdown จะไม่แสดง baseline ที่ตั้ง state เป็น `archived` แล้ว
  (ยกเว้นตัวที่กำลังเป็น official อยู่แล้วก่อนถูก archive)
- **Cloud Sync & Firebase** (`sync`): Firebase Project ID/Firestore path แสดงแบบ read-only (เหตุผลด้าน
  ความปลอดภัย), LocalStorage info + Clear Cache, Automated Rolling Snapshot (`autoSnapshotEnabled`/
  `autoSnapshotIntervalMin` — เรียก `captureBaselineSnapshot()` ผ่าน `setInterval`), Full JSON Database
  Backup, Integrity Checksum (SHA-256 ผ่าน `crypto.subtle.digest`)
- **สิทธิ์และการเข้าถึง** (`security`): แสดงบัญชีที่ล็อกอินจริง + Sign Out (โมเดล 1 บัญชีต่อ 1 แผนงาน ไม่มีระบบ
  role/permission)

### Baseline History & Comparison — `renderBaselinePage()`, nav-rail "📸 Baseline" (หน้าเต็ม)
- **KPI tiles**: Baseline Slippage Impact (Days TF Deficit เทียบ CPM forecast กับ Official Baseline),
  Active Milestones Tracked (Early/On-Time/Delayed), Active Comparison Target
- **Critical Variance banner**: แจ้งเตือนเมื่อมี critical task slip เกินแผนเดิมของ Official Baseline
- **Baseline Version Vault**: ตารางประวัติ snapshot ทุกเวอร์ชัน แสดง Author + **State**
  (`active`/`standby`/`archived`, badge สีคลิกวนสถานะได้ — เป็น metadata การจัดเก็บของผู้ใช้เอง ไม่ผูกกับการ
  คำนวณใดๆ ยกเว้นผลต่อ dropdown Official Baseline ใน Config), ปุ่ม Compare (สลับไป Gantt แสดง overlay
  purple/blue), Restore, Delete
- **Gantt Overlay Analysis**: แสดงเฉพาะ task ที่มีวันที่ต่างจาก Official Baseline จริง (diff-only) — แถบ
  Current (ทึบ) กับ Baseline (กรอบ dashed) overlay ทับกันในแนวเดียวกัน มี slip label, milestone แสดงเป็นเพชร,
  แยกสีตาม critical path
- **Cloud Sync & Audit Trail**: Operator Identity, Cluster Target, Last Remote Sync, SHA-256 Checksum
  Verification, Force Firestore Sync Now, Recent Snapshot Commits

### Working Calendar & Shift Schedule — `renderCalendarPage()`, nav-rail "📅 Calendar" (หน้าเต็ม)
- **KPI tiles**: Working Model (จากจำนวนวันทำงาน/สัปดาห์), Turnaround Mode (จาก headcount ของ `shiftTeams`),
  Planned Exceptions (จำนวน `outageExceptions`), Schedule Engine (จาก `systemConfig.dependencyLagMode`)
- **Calendar grid รายเดือน** (`buildMonthGrid()`): 42 cell (6 สัปดาห์), ระบายสี off-day จาก `isWorkday()`
  (read-only), badge วันหยุด/blackout จาก `outageExceptions` — **แยกจาก workday status โดยสิ้นเชิง ไม่กระทบ
  CPM engine เลย** มีปุ่ม Prev/Next เปลี่ยนเดือน (ไม่ persist, in-memory เท่านั้น)
- **Shift Day/Night Team**: การ์ดแสดง/แก้ไข leadName, leadRole, headcount ต่อ shift (`shiftTeams`)
- **CPM Rules panel**: สรุป read-only ของ `dependencyLagMode`/`cpmFloatThreshold`/workday pattern/
  `dateStrategy` ที่มีอยู่จริงในระบบเท่านั้น (ไม่มี field ปลอมที่ไม่ได้ผูก logic จริง) มีปุ่มลิงก์เปิด Config
  โดยตรงแทนการทำ control ซ้ำซ้อน
- **Outage Workload Hours per Week**: แถบ 4 หมวด (Critical Path/Regular Overtime/NDT & Inspections/
  Standby-Cost-down) รวม `manHours` ตาม `task.workCategory` ที่ผู้ใช้เลือกเอง (ไม่ auto-derive จาก CPM)
- **Outage Exceptions**: เพิ่ม/ลบวันหยุด/blackout date ผ่าน `prompt()` — **display-only บนปฏิทินเท่านั้น**
- ปุ่ม "⚙️ Edit Working Hours & Weekdays" เปิด `#calendarModal` เดิม (ตั้งเวลาทำงาน/วันทำงานรายสัปดาห์จริง)

- **Nav Rail**: สลับ 4 view (Timeline/Progress/Baseline/Calendar) + ปุ่ม Config (เปิด modal แยก) — ดูรายละเอียด
  แต่ละหน้าด้านบน
- **Print / Export A4**: ปุ่ม Export PNG/PDF เรียก `window.print()` พร้อม CSS `@page { size: A4 landscape; }`
  ที่ซ่อน chrome ของแอป (header, drawer, modal, nav rail) ระหว่างพิมพ์
- **Import/Export**:
  - Export JSON (`gantt-plan-v6.json`) — ใช้ `buildStoragePayload()` ตรงๆ จึงครบทุก field ปัจจุบันทั้งหมด
    (tasks, baselineHistory, workingCalendar, timescaleTiers, projectName, systemConfig, projectSafety,
    outageExceptions, shiftTeams)
  - Export CSV/Excel (`gantt-plan-v6.csv`) — เฉพาะ task fields: id/name/type/status/start/end/progress/
    owner/team/priority/criticalOverride/calendarLabel/attachment/budgetCost/actualCost/manHours
    (ยังไม่รวม `workCategory`)
  - Import JSON — แทนที่ tasks/baselineHistory/workingCalendar/timescaleTiers/systemConfig/projectSafety/
    outageExceptions/shiftTeams ทั้งหมด (มี fallback ให้ค่า default ถ้าไฟล์เก่าไม่มี field ใหม่)
- **ไม่มี Undo/Redo** — มีเฉพาะกลไก cancel-restore ใน modal แก้ไข task (บันทึก backup ก่อนแก้ ยกเลิกแล้วคืนค่าเดิม)
- **Modal เพิ่มเติม**:
  - Timescale Settings — เปิด/ปิดแต่ละระดับเวลาบนหัวตาราง
  - Working Time Calendar — เวลาเริ่ม/เลิกงาน, พักเที่ยง, วันทำงานรายสัปดาห์ (ใช้คำนวณวันที่แบบ workday-aware
    และใน CPM)
  - Marks & Highlights — จัดการรายการ mark/highlight แยกจาก modal แก้ไข task ปกติ
  - Baseline History (quick modal, `#historyModal`) — บันทึก snapshot วันที่ปัจจุบันเป็น baseline,
    เปรียบเทียบ (overlay แท่งสีม่วง), restore, ลบ snapshot — กลไกเดียวกับที่ใช้ในหน้า Baseline เต็ม
  - Project Safety & Buffer (`#projectSafetyModal`) — แก้ไข Buffer Days, Lost Time Incidents, Man-Hours
    Logged, Shift Crews (แสดงผลใน Dashboard)
  - "สร้างแผนใหม่..." / "รีเซ็ตเป็นแผนตัวอย่าง" — ล้างกลับไปเป็นข้อมูลตัวอย่างเริ่มต้น (มี confirm)
  - Cloud Sync — ปุ่มดึงข้อมูลล่าสุดจาก Firestore มา re-render, label เปลี่ยนตามสถานะ (ยังไม่ล็อกอิน/กำลัง
    เชื่อมต่อ/ซิงค์แล้ว/error) โดยเช็คทุก 1 วินาที

## 4. Data Model

### Task object (แต่ละรายการใน array `tasks`)

| Field | ชนิด | ความหมาย |
|---|---|---|
| `id` | number | รหัสอัตโนมัติ (`nextId` เพิ่มขึ้นเรื่อยๆ) |
| `name` | string | ชื่อรายการ |
| `type` | `"task"｜"milestone"｜"mark"｜"highlight"` | ประเภทรายการ (มี field `milestone: boolean` แบบเก่าที่ยัง sync ไว้เพื่อ backward-compat) |
| `status` | `"none"｜"inprogress"｜"completed"｜"delay"｜"problem"｜"cancelled"` | สถานะ กำหนดสีเริ่มต้น |
| `color` | string (hex) \| undefined | สีกำหนดเอง ถ้าไม่มีใช้สีตาม `status` |
| `start`, `end` | string `YYYY-MM-DD` | วันที่จริง (สำหรับ milestone/mark, `end === start`) |
| `targetStart`, `targetEnd` | string `YYYY-MM-DD` | วันที่แผน/baseline (ใช้กับเส้น planned ของ S-Curve) |
| `progress` | number 0–100 | % ความคืบหน้า |
| `progressMode` | `"manual"｜"auto"` | `auto` = คำนวณเฉลี่ยจากลูกอัตโนมัติ |
| `deps` | `{ id: number, type: "FS"｜"SS"｜"FF"｜"SF" }[]` | ความสัมพันธ์ก่อน-หลัง (`normalizeDeps` แปลงจากรูปแบบเก่าที่เป็น array ตัวเลขล้วนได้) |
| `parentId` | number \| null | task แม่ (โครงสร้างลำดับชั้น) |
| `collapsed` | boolean | สถานะย่อ/ขยายใน task tree |
| `hidden` | boolean | ซ่อนจาก list ซ้าย (ใช้หลักกับ mark/highlight) |
| `desc` | string | บันทึกรายละเอียด |
| `owner` | string | ผู้รับผิดชอบ/ทีม |
| `attachment` | string (URL) | ลิงก์แนบ (อ่านค่าในแท็บ Attachment ของ modal — **หมายเหตุ**: ควรตรวจสอบเพิ่มว่าค่านี้ถูกบันทึกกลับเข้า task ครบทุกกรณีหรือไม่ ถ้าพบปัญหาการใช้งานจริง) |
| `team` | string | ชื่อทีม/หน่วยงาน (ใช้จัดกลุ่มการ์ดใน Dashboard "Task Distribution & Workload by Team") |
| `priority` | string | หมวดความสำคัญ (`"Critical Component"｜"Major Component"｜"Minor Component"｜"Standard Task"｜""`) |
| `criticalOverride` | boolean | บังคับให้ task เป็น critical path เสมอ ไม่ว่าผล CPM จะคำนวณได้ Total Float เท่าไร |
| `calendarLabel` | string | ป้ายกำกับปฏิทินทำงานของ task นี้ (ปัจจุบันเป็น metadata แสดงผลเท่านั้น ยังไม่ถูกอ่านโดย `isWorkday()`/CPM จริง) |
| `budgetCost`, `actualCost` | number | งบประมาณ/ต้นทุนจริง ใช้ใน EVM (`computeEVM()`: AC มาจาก `actualCost`) และ cost-weighted S-Curve |
| `manHours` | number | ชั่วโมงคน ใช้เป็นน้ำหนักถ่วงแบบ Man-Hour-Weighted (`getTaskWeight`) และรวมเข้าแถบ Outage Workload ตาม `workCategory` |
| `workCategory` | `""｜"critical"｜"overtime"｜"ndt"｜"standby"` | หมวดงานสำหรับตาราง Outage Workload Hours per Week ในหน้า Calendar — ผู้ใช้เลือกเอง ไม่ auto-derive จากผล CPM |

### Baseline snapshot entry (แต่ละรายการใน array `baselineHistory`)

| Field | ชนิด | ความหมาย |
|---|---|---|
| `id` | number | รหัส snapshot |
| `label` | string | ชื่อ snapshot |
| `savedAt` | string (ISO datetime) | เวลาที่บันทึก |
| `author` | string | ผู้บันทึก (จาก `window.__fbUser.name`, fallback `'Unknown'`) |
| `state` | `"active"｜"standby"｜"archived"` | สถานะการจัดเก็บที่ผู้ใช้ตั้งเอง (default `"standby"`) — เป็น metadata คนละแนวคิดกับ `systemConfig.officialBaselineId` ที่ใช้จริงในการคำนวณ; ผลจริงอย่างเดียวคือ baseline ที่ `archived` จะไม่แสดงเป็นตัวเลือกใหม่ใน dropdown Official Baseline ที่ Config |
| `snapshot` | `{ [taskId]: { targetStart, targetEnd, name } }` | วันที่แผนของทุก task ณ ตอนบันทึก |

### Storage payload ระดับบนสุด (`buildStoragePayload()`)

```js
{
  projectName,        // string
  tasks,               // array ของ task object ด้านบน
  baselineHistory,     // array ของ baseline snapshot entry ด้านบน
  currentZoom,         // "day"|"week"|"month"|"quarter"
  showCriticalPath,    // boolean
  showSCurve,          // boolean
  viewMode,            // "auto"|"manual"
  viewStart, viewEnd,  // string YYYY-MM-DD (ใช้เมื่อ viewMode==="manual")
  workingCalendar,     // { startTime, endTime, breakStart, breakEnd, workdays: number[] (0=อาทิตย์..6=เสาร์) }
  timescaleTiers,      // { years, quarters, months, weeks, days } (boolean ทั้งหมด)
  projectSafety,       // { bufferDays, lostTimeIncidents, manHoursLogged, shiftCrews }
  systemConfig,        // { plantFacility, outageCode, targetColdRunDate, gridSyncCOD, progressWeightMethod,
                        //   officialBaselineId, currencyUnit, scurveConfidencePct, cpmFloatThreshold,
                        //   dateStrategy, dependencyLagMode, instantRecalc, autoSnapshotEnabled,
                        //   autoSnapshotIntervalMin }
  outageExceptions,    // [{ date: "YYYY-MM-DD", label: string }] — display-only, key ด้วย date (เพิ่มซ้ำ = upsert label)
  shiftTeams           // { day: { leadName, leadRole, headcount }, night: { leadName, leadRole, headcount } }
}
```

**หมายเหตุ**: `menuExportJSON` เรียก `buildStoragePayload()` ตรงๆ จึง export ได้ payload เต็มรูปแบบทุก field
ด้านบน (ไม่ใช่ subset แบบเดิม) — เหมือนกับที่เก็บใน localStorage/Firestore ทุกประการ

## 5. Storage & Sync

- **localStorage key**: `ganttPlannerData_v6` (ตัวปัจจุบัน) — ถ้าไม่พบจะ fallback ไปอ่าน `ganttPlannerData_v5`
  (ข้อมูลรุ่นเก่า)
- **`saveToStorage()`**: สร้าง payload ด้วย `buildStoragePayload()`, เขียนลง localStorage (v6) และเรียก
  `window.__fbSync(payload)` เพื่อ push ขึ้น Firestore แบบ fire-and-forget — เรียกทุกครั้งที่ `render()` ทำงาน
- **`loadFromStorage()`**: อ่าน v6 (หรือ v5 สำรอง) จาก localStorage แล้วส่งต่อให้ `applyLoadedPayload()`
- **`applyLoadedPayload(payload)`**: รวม field เข้า state ของแอป — เติม `type` ให้ task เก่าที่มีแค่
  `milestone: boolean`, บังคับ `end = start` ให้ milestone/mark, normalize `deps`, เติมค่า default ให้ทุก
  field ที่เพิ่มทีหลัง (`team, priority, criticalOverride, calendarLabel, budgetCost, actualCost, manHours,
  workCategory`) กรณีโหลดข้อมูลเก่าที่ยังไม่มี field เหล่านี้, merge `systemConfig`/`projectSafety` แบบ
  shallow (`{...current, ...loaded}`) เพื่อไม่ให้ field ใหม่หายไปเมื่อโหลด payload เก่า, `outageExceptions`
  overwrite ตรงๆ (fallback `[]` ถ้าไม่มี), `shiftTeams` merge แบบ nested shallow ต่อ sub-object (`day`/
  `night`) แยกกัน, คำนวณ `nextId`/`nextHistId` ใหม่จาก id สูงสุด
- **Firestore**: โครงสร้างเอกสารคือ `plans/{uid}` (collection `plans`, document id = Firebase Auth `uid`)
  - `window.__fbSync(payload)` → `setDoc(doc(db,'plans',uid), payload)`
  - `window.__fbLoad()` → `getDoc(doc(db,'plans',uid))` คืนค่า `snap.data()` หรือ `null`
  - `loadFromCloud()` → เรียก `__fbLoad()` แล้ว apply payload ถ้ามี — เรียกอัตโนมัติหลัง sign-in สำเร็จ และเรียก
    ได้ด้วยตนเองผ่านปุ่ม Cloud Sync
  - ลำดับตอนเปิดแอป: `loadFromStorage()` → แสดงข้อมูล local ทันที → หลัง auth resolve ค่อยดึงจาก cloud มาทับ
- **Scroll sync**: sync แนวตั้งแบบ mirror `scrollTop` ตรงๆ ระหว่าง `#taskTreeContainer` กับ
  `#timelineScrollBody`; sync แนวนอนด้วย `transform: translateX()` กับ header sticky และ S-Curve panel
  (เพราะทั้งสองเป็น `overflow:hidden` ไม่มี scrollbar ของตัวเอง)

## 6. Authentication

- ใช้ **Firebase Authentication + Google Sign-In** (`GoogleAuthProvider`, `signInWithPopup`) — ไม่มี anonymous
  auth แล้ว (ถูกถอดออกหลังพบปัญหา session ค้าง)
- `onAuthStateChanged`:
  - ถ้าเป็น user แบบ anonymous (ตกค้างจากเวอร์ชันเก่า) → sign-out ทันที เพื่อกันบายพาสด่าน login
  - ถ้า sign-in สำเร็จ → เก็บ `{uid, name, email, photo}` ไว้ที่ `window.__fbUser`, status เป็น `'ready'`,
    เรียก `window.__onAuthReady(user)`
  - ถ้า sign-out → เคลียร์ state, เรียก `window.__onSignedOut()`
- **App-side handlers**: `__onAuthReady` ปิด login overlay + แสดงชื่อ/อีเมลใน drawer + `loadFromCloud()` +
  re-render; `__onSignedOut` เปิด login overlay กลับมา; `__onAuthError` แสดงข้อความ error ใน `#loginStatusMsg`
- **Login overlay** (`#loginOverlay`) เปิดค้างไว้เป็นค่าเริ่มต้นจนกว่า auth จะ resolve — เป็นด่านที่บล็อกการใช้
  แอปทั้งหมดจนกว่าจะ sign-in สำเร็จ
- Sign-out ทำผ่านเมนู drawer (`#menuSignOut`)

## 7. Firebase Setup

- **Project ID**: `maintenance-project-planner-db`
- **Firebase JS SDK**: v10.13.2 (โหลดผ่าน CDN แบบ ES module ในหัวไฟล์ `index.html`)
- **Firebase config** (`apiKey`, `authDomain`, ฯลฯ) อยู่ในบล็อก `<script type="module">` ต้นไฟล์ `index.html`
  (ไม่คัดลอกมาซ้ำในเอกสารนี้เพื่อลดจุดที่ต้องอัปเดตถ้ามีการหมุน key — ค่านี้เป็น Firebase Web config ที่ตั้งใจ
  ให้ public อยู่แล้ว ความปลอดภัยจริงอยู่ที่ Firestore Security Rules + Auth ไม่ใช่การซ่อน apiKey)
- **ไฟล์ config ที่เกี่ยวข้องในโปรเจกต์**:
  - `.mcp.json` — ผูก Firebase MCP server (`npx -y firebase-tools@latest experimental:mcp`)
  - `.firebaserc` — ตั้ง default project เป็น `maintenance-project-planner-db`
  - `firebase.json` — ชี้ไปที่ `firestore.rules`
  - `firestore.rules` — จำกัดสิทธิ์ `plans/{uid}` ให้เฉพาะ `request.auth.uid == uid` เท่านั้น

## 8. ฟังก์ชันหลัก (Key Functions Reference)

**Date / Working Calendar**
- `parseDate`, `fmtDate`, `addDays`, `diffDays` — utility จัดการวันที่ (local-date, กัน UTC drift)
- `isWorkday`, `getNextWorkday`, `calculateEndDateByWorkdays`, `calculateStartDateFromEnd`,
  `countWorkdaysBetween` — คำนวณวันที่โดยข้ามวันหยุดตาม `workingCalendar`

**Dependencies**
- `parseDepsInput`, `formatDepsString`, `normalizeDeps` — แปลงระหว่างข้อความ (`"1FS, 2SS"`) กับ object
  `{id,type}`
- `wouldCreateCycle(sourceId, targetId)` — ตรวจจับ cycle ด้วย DFS ก่อนสร้าง dependency ใหม่
- `attachLinkHandle`, `updateTempLinkLine`, `finishLinking`, `resolveDepType` — กลไกลากเชื่อม dependency ด้วย
  เมาส์

**Persistence**
- `buildStoragePayload`, `saveToStorage`, `applyLoadedPayload`, `loadFromStorage`, `loadFromCloud` — ดูหัวข้อ 5

**Hierarchy & Rollup**
- `hasChildren`, `isCollapsedAncestor`, `taskDepth` — ช่วยจัดการโครงสร้างลำดับชั้น
- `applyRollups()` — คำนวณ `progress` ของ parent แบบ `auto` ใหม่จากค่าเฉลี่ยของลูก

**Critical Path & EVM**
- `computeCriticalPath()` — เอนจิน CPM เต็มรูปแบบ (forward/backward pass, lag 4 แบบตาม
  `systemConfig.dependencyLagMode`, float threshold ตาม `systemConfig.cpmFloatThreshold`, total float,
  จุด/เส้นทาง critical, ระยะเวลารวมของ critical path) — cache ผลลัพธ์ไว้ (`cachedCP`) ถ้า
  `systemConfig.instantRecalc` เปิดอยู่ ต้องกด Recalculate ถึงคำนวณใหม่
- `getTaskWeight(t)` — คืนน้ำหนักถ่วงของ task ตาม `systemConfig.progressWeightMethod`
  (duration/manhour/cost) ใช้ร่วมกันทั้งใน `renderSCurve()` และ Dashboard
- `computeEVM()` — คำนวณ PV/EV/AC/SPI/CPI จาก `budgetCost`/`actualCost`/`getTaskWeight`
- `computeBufferDepletion(cp)` — เทียบ CPM forecast finish กับแผนจริง หารด้วย `projectSafety.bufferDays`
  (metric แบบง่าย ไม่ใช่ CCPM เต็มรูปแบบ)

**Rendering**
- `render()` — ฟังก์ชันหลักที่ orchestrate การ re-render ทั้งหมด: `applyRollups()` →
  `renderTaskTree()` → `renderTimeline()` → `syncRangeInputs()` → `saveToStorage()`
- `renderTaskTree()` — สร้าง DOM ของ task list ฝั่งซ้าย พร้อม drag/drop, ปุ่มเยื้อง/แก้ไข/เพิ่ม sub-task
- `autoTimeBounds()`, `getTimeBounds()`, `syncRangeInputs()` — คำนวณ/ซิงค์ช่วงวันที่ที่แสดงผล
- `renderTimeline()` — เรนเดอร์ Gantt หลัก (หัวตาราง, กริดวันหยุด, เส้นวันนี้, แท่งงาน/milestone/mark/highlight,
  แท่งเทียบ baseline, เส้น dependency, ผูก mouse handler ลาก/ปรับขนาด) แล้วเรียก `renderSCurve()` ต่อท้าย
- `pctAt(d, s, e)` — คำนวณ % ความคืบหน้าเชิงเส้นของวันที่ `d` ระหว่างช่วง `s`–`e`
- `renderSCurve(min, max, dayWidth, totalWidth)` — สร้างกราฟ S-Curve (planned vs actual) แบบถ่วงน้ำหนักตาม
  ระยะเวลา
- `switchView(view)` — สลับการแสดงผลระหว่าง 4 view: `"gantt"｜"dashboard"｜"baseline"｜"calendar"`
  (แสดง/ซ่อน container ที่เกี่ยวข้อง แล้วเรียก `renderDashboard()`/`renderBaselinePage()`/
  `renderCalendarPage()` ตามลำดับ — Config ไม่ใช่ view แต่เปิด `openConfigModal()` แยก)
- `renderDashboard()` — คำนวณและเรนเดอร์ทุกอย่างในหน้า Progress/Dashboard รวม EVM (ใช้ helper เดียวกับ
  Gantt/S-Curve ซ้ำ ไม่ duplicate logic)
- `renderBaselinePage()` — เรนเดอร์หน้า Baseline History & Comparison เต็มหน้า (KPI tiles, Version Vault,
  Gantt Overlay Analysis แบบ diff-only, Cloud Sync Audit Trail)
- `renderCalendarPage()`, `buildMonthGrid(year, month)` — เรนเดอร์หน้า Working Calendar & Shift Schedule
  (`buildMonthGrid` สร้าง 42 cell/6 สัปดาห์ ให้ `renderCalendarPage()` วาดกริดปฏิทิน)

**Modals**
- `openTimescaleModal`, `openModal`/`closeModal`/`switchTab`, `liveSyncModalChanges` — ควบคุม modal แก้ไข task
  (พรีวิวสดระหว่างแก้ + backup/restore เมื่อกด cancel)
- `openCalendarModal()` — modal ตั้งเวลาทำงาน/วันหยุดรายสัปดาห์ (เข้าถึงผ่านปุ่ม "Edit Working Hours &
  Weekdays" ในหน้า Calendar หรือเมนู drawer เดิม)
- `openProjectSafetyModal()` — modal แก้ไข Buffer Days/Lost Time Incidents/Man-Hours Logged/Shift Crews
- `openConfigModal()`, `switchConfigTab(tabName)` — modal System & Project Configuration 4 แท็บ
- `renderMHModal()` — modal จัดการ Marks & Highlights
- `captureBaselineSnapshot(label)`, `renderHistoryModal()` — จัดการ Baseline History (ใช้ร่วมกันทั้ง quick
  modal เดิมและหน้า Baseline เต็มหน้าใหม่)

**อื่นๆ**
- `updateToggleBtnStyles()` — sync สถานะ active ของปุ่ม Critical Path / S-Curve
- `openDrawer`/`closeDrawer`, `openHelp`/`closeHelp` — เปิด/ปิด overlay เมนู/คู่มือ
- `triggerA4Print()` — เรียก `window.print()` (พึ่ง CSS `@media print` จัด layout A4)
- `setupScrollSync()`, `setupHorizontalScrollSync()` — IIFE ผูก scroll-sync ระหว่าง task list กับ Gantt (ดู
  หัวข้อ 5)
- `updateCloudSyncBtnLabel()`, `handleCloudSyncClick()` — จัดการปุ่ม Cloud Sync

## 9. External Dependencies

- **Firebase JS SDK v10.13.2** เท่านั้น โหลดผ่าน CDN แบบ ES module (`firebase-app.js`, `firebase-auth.js`,
  `firebase-firestore.js` จาก `https://www.gstatic.com/firebasejs/10.13.2/...`)
- ไม่มี chart library ภายนอก — Gantt bar และ S-Curve เขียนด้วย raw SVG/DOM เอง (ไม่ใช้ D3, Chart.js ฯลฯ)
- ไม่มี icon library — ใช้ emoji ธรรมดา (📊 📈 🎯 ☁️ ฯลฯ)
- **Google Fonts CDN** (`fonts.googleapis.com`/`fonts.gstatic.com`): Be Vietnam Pro (`--font-sans`),
  JetBrains Mono (`--font-mono`), Space Grotesk (`--font-headline`) — ธีมมืด "dark industrial" ใช้ฟอนต์
  เหล่านี้แทน system font stack เดิม
- ไม่มี framework/library JS อื่นใด (vanilla JS ล้วน)

## 10. Known Limitations / หมายเหตุ

- ไม่มีระบบ Undo/Redo ระดับแอป มีเฉพาะ cancel-restore ในหน้าต่างแก้ไข task เดี่ยวๆ
- ยังไม่มี automated test framework — วิธี verify คือเปิดแอปในเบราว์เซอร์แล้วตรวจด้วยตา (manual QA) ตามที่ระบุใน
  `.claude/CLAUDE.md`
- field `attachment` ของ task ถูกอ่าน/แสดงในแท็บ Attachment ของ modal แต่ยังไม่ได้ตรวจสอบละเอียดว่าบันทึกค่า
  กลับเข้า task ครบทุก edge case หรือไม่ — ควรตรวจเพิ่มถ้าพบปัญหาจากการใช้งานจริง
- ข้อมูลตัวอย่าง/ทดสอบทั้งหมดใน repo เป็น dummy data เท่านั้น (ห้ามใส่ข้อมูลโรงงานจริงตาม Data Safety rule ใน
  `.claude/CLAUDE.md`)
- panel "CPM Rules" ในหน้า Calendar เป็น **read-only** เท่านั้น (สรุปค่าจริงจาก `systemConfig`/
  `workingCalendar` มาแสดง ไม่ใช่ control แก้ไข) — ต้องแก้ค่าจริงที่ Config > CPM Engine เท่านั้น เพื่อไม่ให้
  มี control ซ้ำซ้อนที่อาจ drift ไม่ตรงกัน
- `outageExceptions` (วันหยุด/blackout date ในหน้า Calendar) เป็น **display-only โดยเจตนา** — ไม่ถูกอ่านโดย
  `isWorkday()`/`getNextWorkday()`/`calculateEndDateByWorkdays()`/`calculateStartDateFromEnd()`/
  `countWorkdaysBetween()`/`computeCriticalPath()` เลย ถ้าต้องการวันหยุดที่มีผลต่อการคำนวณ CPM จริงต้องตั้งที่
  `workingCalendar.workdays` (รายสัปดาห์) ผ่าน `#calendarModal` เท่านั้น
- `task.calendarLabel` และ `task.workCategory` เป็น metadata ที่ผู้ใช้กรอกเอง ไม่ได้ผูกกับการคำนวณวันที่/CPM
  ใดๆ (เป็นการตั้งใจออกแบบไว้ ไม่ใช่บั๊ก)
