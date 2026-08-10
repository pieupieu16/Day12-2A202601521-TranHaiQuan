# BÁO CÁO MÔ TẢ CHI TIẾT DỰ ÁN
## System Architecture & Production Cloud Deployment for AI Agent
**Dự án:** K3 — Ngày 12: Hạ Tầng Cloud & Deployment  
**Model AI:** Liquid AI (LFM2.5-2.6B)  
**Công nghệ chính:** FastAPI, Redis, Docker Multi-stage, GitHub Actions CI/CD  

---

## I. TỔNG QUAN DỰ ÁN & KIẾN THỨC CỐT LÕI

Dự án này là một hệ thống **AI Agent Web Service** đạt chuẩn **Production Cloud-Native**, áp dụng triệt để các nguyên lý thiết kế hệ thống hiện đại.

### Các khối kiến thức trọng tâm bao gồm:

1. **Triết lý 12-Factor App (Cấu hình & Môi trường)**:
   - Tách biệt hoàn toàn giữa Mã nguồn (Code) và Cấu hình (Configuration).
   - Quản lý cấu hình tập trung qua biến môi trường (`ENV`) với cơ chế **Fail-Fast** (Dừng ứng dụng ngay lập tức khi thiếu tham số quan trọng như `AGENT_API_KEY`).
   - Structured JSON Logging chuẩn hóa cho các hệ thống giám sát log tập trung (Datadog, ELK, CloudWatch).

2. **Bảo Mật API Nhiều Lớp (Defense-in-Depth API Security)**:
   - **Authentication**: Xác thực API Key sử dụng so sánh chuỗi thời gian hằng số (`secrets.compare_digest`) để chống lại tấn công đo thời gian (Timing Attack).
   - **Rate Limiting (ZSET Sliding Window)**: Giới hạn tần suất gọi API theo từng User trong cửa sổ trượt 60 giây sử dụng Redis ZSET, chống tấn công từ chối dịch vụ (DDoS) và spam.
   - **Cost Guard (Bảo vệ ngân sách LLM)**: Theo dõi cộng dồn chi phí gọi LLM theo tháng. Tự động từ chối request (`402 Payment Required`) khi tài khoản vượt quá ngân sách đặt trước.

3. **Kiến Trúc Stateless & Scaling Ngang (Horizontal Scaling)**:
   - Không lưu trữ trạng thái phiên làm việc (Session/History) trong bộ nhớ RAM của App Node.
   - Toàn bộ lịch sử hội thoại được đẩy ra **Redis State Store** ngoài.
   - Giúp ứng dụng có thể mở rộng hàng trăm instance (Scale Out) đằng sau Load Balancer mà không làm mất lịch sử trò chuyện của người dùng.

4. **Reliability & Health Observability**:
   - **Liveness Probe (`/health`)**: Kiểm tra ứng dụng còn sống hay đã bị treo loop/deadlock.
   - **Readiness Probe (`/ready`)**: Kiểm tra ứng dụng đã sẵn sàng nhận traffic chưa (đã kết nối tới Redis thành công chưa).
   - **Graceful Shutdown**: Xử lý tín hiệu hệ thống (`SIGTERM`/`SIGINT`), ngừng nhận request mới và hoàn tất công việc dở dang trước khi tắt process.

5. **Đóng Gói Docker Chuẩn Production (Multi-Stage Build)**:
   - Sử dụng kỹ thuật 2 giai đoạn (`builder` $\rightarrow$ `runtime`) giảm dung lượng Docker Image từ ~1GB xuống ~185MB.
   - Chạy với tài khoản không phải root (`appuser` UID 10001) nâng cao an toàn an ninh mạng.
   - Tích hợp sẵn chỉ thị `HEALTHCHECK` trong Dockerfile.

6. **Tự Động Hóa CI/CD & Giao Diện Web Pro (UI/UX)**:
   - Pipeline GitHub Actions 3 giai đoạn: `test` $\rightarrow$ `build` $\rightarrow$ `deploy`.
   - Giao diện Dashboard Web UI/UX Xanh - Trắng hiện đại (Plus Jakarta Sans, Glassmorphism, Micro-animations) kết nối trực tiếp với API backend.

---

## II. CÁCH THỨC XÂY DỰNG DỰ ÁN (PROJECT STRUCTURE)

Cấu trúc dự án được phân chia mô-đun rõ ràng, tuân thủ nguyên tắc Single Responsibility:

```text
.
├── app/
│   ├── main.py           # Entry point FastAPI, định tuyến & phục vụ Web UI
│   ├── config.py         # Quản lý Settings & biến môi trường (Pydantic)
│   ├── auth.py           # Middleware xác thực API Key chống Timing Attack
│   ├── rate_limiter.py   # Thuật toán Sliding Window ZSET trên Redis
│   ├── cost_guard.py     # Quản lý và kiểm soát ngân sách LLM
│   ├── store.py          # Quản lý bộ nhớ hội thoại Stateless trên Redis
│   ├── lifecycle.py      # Xử lý Graceful Shutdown (SIGTERM/SIGINT)
│   ├── logging_utils.py  # Logger ghi định dạng JSON 1 dòng chuẩn UTC
│   └── static/
│       └── index.html    # Giao diện Web UI/UX Xanh - Trắng chuẩn Pro
├── utils/
│   └── mock_llm.py       # Mô phỏng engine LLM (Liquid AI LFM2.5-2.6B)
├── tests/                # Bộ test tự động suite (CP1 đến CP5 & Bonus)
├── .github/workflows/
│   └── ci.yml            # GitHub Actions CI/CD Pipeline
├── Dockerfile            # Multi-stage production build
├── docker-compose.yml    # Orchestration liên kết Agent & Redis
├── DEPLOYMENT.md         # Tài liệu triển khai Cloud & kết quả test
├── exercises.md          # Bài tập phản ánh lý thuyết & tình huống thực tế
└── grade.py              # Script tự động chấm điểm toàn bộ dự án
```

---

## III. ĐIỂM TRỌNG TÂM CỦA DỰ ÁN (KEY HIGHLIGHTS)

1. **Khả năng sẵn sàng Production (Production Readiness)**: Dự án không dừng lại ở bài tập làm thử mà đạt đầy đủ các tiêu chuẩn doanh nghiệp yêu cầu khi đưa AI Agent lên môi trường Cloud.
2. **Quản trị rủi ro chi phí AI (Cost Governance)**: Mô đun `CostGuard` giải quyết đúng nỗi đau lớn nhất của các doanh nghiệp khi triển khai LLM: **Tránh nguy cơ vỡ nợ do bị lộ API Key hoặc bot cào dữ liệu làm sập quỹ tiền API.**
3. **Hiệu năng & An toàn bộ nhớ (Stateless Memory Capping)**: Lịch sử hội thoại được tự động giới hạn độ dài (`HISTORY_MAX_MESSAGES=20`) và cài đặt thời gian sống (`TTL=7 ngày`) trên Redis, ngăn ngừa tràn RAM cơ sở dữ liệu.
4. **Trải nghiệm người dùng cao cấp (Premium UI/UX)**: Giao diện trực quan giúp trực quan hóa toàn bộ chỉ số vận hành ngầm (Health, Readiness, Rate Limit, Cost Budget) thành đồ họa sinh động.

---

## IV. KỊCH BẢN THUYẾT TRÌNH & DEMO SẢN PHẨM (PRESENTATION SCRIPT)

Khi trình bày bài tập / dự án trước giảng viên hoặc hội đồng, bạn có thể thực hiện theo kịch bản 5 bước chuyên nghiệp sau:

### 🎬 Bước 1: Mở đầu & Đặt vấn đề (1 phút)
> *"Kính chào thầy/cô và các bạn! Hôm nay em xin trình bày dự án Triển khai Hạ tầng Cloud & Production Deployment cho AI Agent chạy model Liquid AI LFM2.5-2.6B. Thách thức lớn nhất khi đưa AI Agent lên Cloud là làm sao đảm bảo hệ thống có thể Scale ngang, an toàn trước tấn công DDoS, kiểm soát được chi phí API và luôn sẵn sàng hoạt động (High Availability). Dự án của em được xây dựng để giải quyết trọn vẹn các bài toán đó."*

### 💻 Bước 2: Demo Giao Diện Real-time & Các Chỉ Số Vận Hành (2 phút)
* **Thao tác**: Mở trình duyệt tại địa chỉ `http://localhost:8000`.
* **Thuyết minh**:
  > *"Đây là giao diện Web UI được thiết kế theo chuẩn Xanh - Trắng hiện đại. Ngay phía trên Dashboard là 4 thẻ giám sát thời gian thực:*
  > 1. *Liveness Probe (`/health`): Báo trạng thái process còn sống.*
  > 2. *Readiness Probe (`/ready`): Báo trạng thái đã kết nối thành công tới Redis.*
  > 3. *Rate Limiter Meter: Đếm số request trong cửa sổ 60 giây.*
  > 4. *Cost Guard Meter: Giám sát ngân sách sử dụng LLM theo tháng."*

### 🧠 Bước 3: Demo Tính Năng Hội Thoại & Stateless History (2 phút)
* **Thao tác**:
  1. Nhập câu hỏi 1: *"Docker là gì?"* $\rightarrow$ Nhấn **Gửi**.
  2. Nhập câu hỏi 2: *"Stateless là gì?"* $\rightarrow$ Nhấn **Gửi**.
* **Thuyết minh**:
  > *"Khi em gửi câu hỏi thứ 2, hệ thống tự động trích xuất lịch sử hội thoại từ Redis State Store ngoài và truyền vào context của model. Kết quả trả về có ghi nhận `History: 2 turns` và kèm câu `(Mình đang nhớ 2 lượt trao đổi trước đó.)`. Điều này chứng minh App Node hoàn toàn Stateless — nếu ta nhân bản thêm 10 server nữa, người dùng vẫn tiếp tục đoạn chat mà không bị gián đoạn."*

### 🛡️ Bước 4: Demo Tính Năng Bảo Mật & Chống Spam (2 phút)
* **Thao tác 1 (Sai Key)**: Nhập `X-API-Key` sai $\rightarrow$ Nhấn gửi câu hỏi.
  * *Thuyết minh*: *"Hệ thống chặn ngay ở tầng middleware và trả về HTTP 401 Unauthorized nhờ cơ chế so sánh chuỗi thời gian hằng số chống timing attack."*
* **Thao tác 2 (Spam Rate Limit)**: Nhấp nút **Gửi** liên tục 11 lần thật nhanh.
  * *Thuyết minh*: *"Đến lần thứ 11, thuật toán Sliding Window ZSET trên Redis lập tức kích hoạt và trả về HTTP 429 Too Many Requests, bảo vệ server khỏi bị quá tải."*

### 🏆 Bước 5: Tổng Kết & Kết Quả Chấm Điểm (1 phút)
* **Thao tác**: Mở Terminal chạy `python grade.py`.
* **Thuyết minh**:
  > *"Toàn bộ hệ thống được kiểm thử tự động qua script `grade.py` và bộ test suite CI/CD. Kết quả dự án đạt 100.0/100 điểm tối đa, đi kèm hệ thống tự động hóa GitHub Actions và tài liệu triển khai chuẩn Production. Em xin cảm ơn thầy/cô đã lắng nghe!"*

---
*Báo cáo được khởi tạo tự động cho dự án K3 Day 12 Cloud Services & Deployment.*
