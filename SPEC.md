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
      .nav-rail#navRail                 ← rail ไอคอนซ้ายสุด สลับ view (Gantt/Dashboard)
      .task-sidebar#taskSidebar → .task-tree-container#taskTreeContainer  ← ต้นไม้ Task ฝั่งซ้าย
      .timeline-wrapper#timelineWrapper
        .timeline-header-clip → .timeline-header-sticky   ← หัวตารางวันที่ (fixed, ไม่ scroll เอง)
        .timeline-scroll-body#timelineScrollBody → .timeline-body-area#timelineBodyArea + <svg#dependencySvg>
      .scurve-row-spacer#scurveRowSpacer + .scurve-clip#scurveClip → #scurveContainer   ← แผง S-Curve
      .dashboard-view#dashboardView     ← หน้า Dashboard (ซ่อนเมื่อไม่ได้เลือก)
  Modals (.modal-backdrop, เปิด/ปิดด้วย class .open):
    #timescaleModal   — ตั้งค่าระดับเวลาที่แสดงบนหัวตาราง
    #taskModal        — แก้ไข Task (แท็บ General/Description/Resources/Attachment)
    #calendarModal    — ปฏิทินเวลาทำงาน (Working Time Calendar)
    #mhModal          — จัดการ Marks & Highlights
    #historyModal     — ประวัติ Baseline
  <input type="file" id="fileImportInput" hidden>   ← ใช้ import JSON
```

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
- **S-Curve**: ปุ่ม `#btnToggleSCurve` — กราฟความคืบหน้าสะสมแบบถ่วงน้ำหนักตามระยะเวลา (planned vs actual) แสดง
  ใต้ Gantt และแสดงซ้ำแบบย่อใน Dashboard
- **Dashboard**: % ความคืบหน้ารวม, จำนวน task ทั้งหมด, สรุป Critical Path, จำนวน task เกินกำหนด, กราฟสถานะแบบ
  stacked bar, กราฟ S-Curve แบบย่อ, รายการ task ที่เกินกำหนด (ช้ากี่วัน), รายการ milestone ที่ใกล้ถึง
- **Nav Rail**: สลับ 2 มุมมอง — "Gantt" (📊, ค่าเริ่มต้น) และ "Dashboard" (📈)
- **Print / Export A4**: ปุ่ม Export PNG/PDF เรียก `window.print()` พร้อม CSS `@page { size: A4 landscape; }`
  ที่ซ่อน chrome ของแอป (header, drawer, modal, nav rail) ระหว่างพิมพ์
- **Import/Export**:
  - Export JSON (`gantt-plan-v6.json`) — ครบทุกอย่าง (tasks, baselineHistory, workingCalendar, timescaleTiers,
    projectName)
  - Export CSV/Excel (`gantt-plan-v6.csv`) — id/name/type/status/start/end/progress/owner
  - Import JSON — แทนที่ tasks/baselineHistory/workingCalendar/timescaleTiers ทั้งหมด
- **ไม่มี Undo/Redo** — มีเฉพาะกลไก cancel-restore ใน modal แก้ไข task (บันทึก backup ก่อนแก้ ยกเลิกแล้วคืนค่าเดิม)
- **Modal เพิ่มเติม**:
  - Timescale Settings — เปิด/ปิดแต่ละระดับเวลาบนหัวตาราง
  - Working Time Calendar — เวลาเริ่ม/เลิกงาน, พักเที่ยง, วันทำงานรายสัปดาห์ (ใช้คำนวณวันที่แบบ workday-aware
    และใน CPM)
  - Marks & Highlights — จัดการรายการ mark/highlight แยกจาก modal แก้ไข task ปกติ
  - Baseline History — บันทึก snapshot วันที่ปัจจุบันเป็น baseline, เปรียบเทียบ (overlay แท่งสีม่วง), restore,
    ลบ snapshot
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

### Storage payload ระดับบนสุด (`buildStoragePayload()`)

```js
{
  projectName,        // string
  tasks,               // array ของ task object ด้านบน
  baselineHistory,     // [{ id, label, savedAt (ISO string), snapshot: { [taskId]: { targetStart, targetEnd, name } } }]
  currentZoom,         // "day"|"week"|"month"|"quarter"
  showCriticalPath,    // boolean
  showSCurve,          // boolean
  viewMode,            // "auto"|"manual"
  viewStart, viewEnd,  // string YYYY-MM-DD (ใช้เมื่อ viewMode==="manual")
  workingCalendar,     // { startTime, endTime, breakStart, breakEnd, workdays: number[] (0=อาทิตย์..6=เสาร์) }
  timescaleTiers       // { years, quarters, months, weeks, days } (boolean ทั้งหมด)
}
```

**หมายเหตุ**: ไฟล์ export เป็น JSON (`menuExportJSON`) เก็บเฉพาะ subset — `projectName, tasks, baselineHistory,
workingCalendar, timescaleTiers` เท่านั้น (ไม่รวม zoom/view/CP/SCurve state) ต่างจาก payload เต็มที่เก็บใน
localStorage/Firestore

## 5. Storage & Sync

- **localStorage key**: `ganttPlannerData_v6` (ตัวปัจจุบัน) — ถ้าไม่พบจะ fallback ไปอ่าน `ganttPlannerData_v5`
  (ข้อมูลรุ่นเก่า)
- **`saveToStorage()`**: สร้าง payload ด้วย `buildStoragePayload()`, เขียนลง localStorage (v6) และเรียก
  `window.__fbSync(payload)` เพื่อ push ขึ้น Firestore แบบ fire-and-forget — เรียกทุกครั้งที่ `render()` ทำงาน
- **`loadFromStorage()`**: อ่าน v6 (หรือ v5 สำรอง) จาก localStorage แล้วส่งต่อให้ `applyLoadedPayload()`
- **`applyLoadedPayload(payload)`**: รวม field เข้า state ของแอป — เติม `type` ให้ task เก่าที่มีแค่
  `milestone: boolean`, บังคับ `end = start` ให้ milestone/mark, normalize `deps`, คำนวณ `nextId`/`nextHistId`
  ใหม่จาก id สูงสุด
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

**Critical Path**
- `computeCriticalPath()` — เอนจิน CPM เต็มรูปแบบ (forward/backward pass, lag 4 แบบ, total float, จุด/เส้นทาง
  critical, ระยะเวลารวมของ critical path)

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
- `switchView(view)` — สลับการแสดงผลระหว่าง Gantt กับ Dashboard
- `renderDashboard()` — คำนวณและเรนเดอร์ทุกอย่างในหน้า Dashboard (ใช้ helper เดียวกับ Gantt/S-Curve ซ้ำ ไม่
  duplicate logic)

**Modals**
- `openTimescaleModal`, `openModal`/`closeModal`/`switchTab`, `liveSyncModalChanges` — ควบคุม modal แก้ไข task
  (พรีวิวสดระหว่างแก้ + backup/restore เมื่อกด cancel)
- `openCalendarModal()` — modal ปฏิทินเวลาทำงาน
- `renderMHModal()` — modal จัดการ Marks & Highlights
- `captureBaselineSnapshot(label)`, `renderHistoryModal()` — จัดการ Baseline History

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
- ไม่มี web font จาก CDN — ใช้ system font stack (`-apple-system, "Segoe UI", "Noto Sans Thai", Roboto, Arial,
  sans-serif`)
- ไม่มี framework/library JS อื่นใด (vanilla JS ล้วน)

## 10. Known Limitations / หมายเหตุ

- ไม่มีระบบ Undo/Redo ระดับแอป มีเฉพาะ cancel-restore ในหน้าต่างแก้ไข task เดี่ยวๆ
- ยังไม่มี automated test framework — วิธี verify คือเปิดแอปในเบราว์เซอร์แล้วตรวจด้วยตา (manual QA) ตามที่ระบุใน
  `.claude/CLAUDE.md`
- field `attachment` ของ task ถูกอ่าน/แสดงในแท็บ Attachment ของ modal แต่ยังไม่ได้ตรวจสอบละเอียดว่าบันทึกค่า
  กลับเข้า task ครบทุก edge case หรือไม่ — ควรตรวจเพิ่มถ้าพบปัญหาจากการใช้งานจริง
- ข้อมูลตัวอย่าง/ทดสอบทั้งหมดใน repo เป็น dummy data เท่านั้น (ห้ามใส่ข้อมูลโรงงานจริงตาม Data Safety rule ใน
  `.claude/CLAUDE.md`)
