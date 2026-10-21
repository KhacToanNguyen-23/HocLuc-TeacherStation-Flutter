# Phase 03 — Hỗ trợ giáo viên trong lúc dạy

Status: Code implemented; real receiver acceptance pending. Covers R05, preview R06.

## Công việc

- Nối cue stable IDs tới current presented activity/page; reuse StudioSpeakerNotesBar/audience protection, không bỏ verified-source gate.
- PDF dùng active document fingerprint + pageIndex thay board.currentPageNote. Editor selection không thay audience output nếu chưa present; notes đi theo actual output. Auto-follow/pin/reset đã được người dùng xác nhận.
- Panel trong app cho note/đáp án/lời nhắc theo nội dung; pin/reset, navigation và nhãn mất kết nối rõ.
- Preview giáo viên/học sinh trước dạy. Không coi preview hoặc app window screenshot là bằng chứng receiver an toàn.
- Chính sách source chưa verified fail closed; whole desktop share không được hứa private notes. Ordinary Google Meet cho học sinh; không student app hay chuyển notes ra tab khác bắt buộc.

## Gate

A15–18 với receiver thiết bị/tài khoản khác, kể cả reconnect/source change. Có bằng chứng note trang 3 tự hiện chỉ bên giáo viên. Bất kỳ leak nào chặn phase acceptance.
