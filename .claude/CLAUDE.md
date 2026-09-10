# CLAUDE.md

## Project Overview
Maintenance Project Planner — Gantt chart planner สำหรับงาน maintenance/factory project
เป็น static single-file app (index.html เดียว รวม HTML+CSS+JS) ไม่มี build step
เก็บข้อมูลใน browser localStorage เป็นหลัก มี optional Google Drive sync (OAuth)

## Stack & Conventions
- Vanilla JavaScript (ไม่มี framework, ไม่มี npm/package.json)
- ไม่มี build tool — แก้ไฟล์ index.html แล้วเปิดตรงในเบราว์เซอร์ได้เลย
- Indent: 2 spaces
- ภาษาที่ใช้ใน UI/comment: ไทยเป็นหลัก

## Test / Verify command
ยังไม่มี test framework ในโปรเจกต์นี้
วิธี verify: เปิด index.html ใน browser ด้วยตนเอง แล้วเช็คด้วยตา (manual QA)

## Data Safety — สำคัญ
- ห้ามใส่ข้อมูลโรงงานจริง (ชื่อเครื่องจักร, ชื่อ plant, ค่าจริง) ลงใน repo นี้เด็ดขาด
- Repo นี้ใช้ dummy/sample data เท่านั้น

## Scope Guard
- แก้เฉพาะจุดที่สั่ง ห้าม refactor ไฟล์อื่นหรือส่วนอื่นที่ไม่เกี่ยวโดยไม่บอกก่อน
- ห้ามแก้ไฟล์ config ที่เกี่ยวกับ Google OAuth Client ID โดยไม่ถามก่อนเสมอ
