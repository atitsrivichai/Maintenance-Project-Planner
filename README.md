# Maintenance Project Planner

Gantt Chart Planner สำหรับวางแผนงาน Maintenance/โปรเจกต์ ทำงานเป็นไฟล์ HTML เดี่ยว (single-file app) รันบนเบราว์เซอร์ 100% ไม่ต้องติดตั้งหรือเชื่อมต่อเซิร์ฟเวอร์ ข้อมูลบันทึกอัตโนมัติไว้ใน localStorage ของเบราว์เซอร์

## ฟีเจอร์หลัก
- จัดการ Task แบบ Tree พร้อม Sub-task และลาก-วางจัดลำดับ
- Gantt Chart พร้อมเชื่อม Dependency (FS/SS/FF/SF)
- คำนวณ Critical Path (CPM) แบบ Full Lag
- กราฟ S-Curve (Duration-Weighted Progress)
- Baseline Snapshot & Compare
- Marks / Milestones / Highlights บนไทม์ไลน์
- Import/Export JSON, CSV และพิมพ์ A4
- ซิงค์ข้อมูลกับ Google Drive (ต้องใช้ Google OAuth Client ID ของตนเอง)

## วิธีใช้งาน
เปิดไฟล์ `index.html` ด้วยเบราว์เซอร์โดยตรง ไม่ต้องติดตั้งหรือ build ใดๆ
