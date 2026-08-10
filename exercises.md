# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng câu trả lời của bạn bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trịnh Văn An  Mã học viên: K3-20k-01

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Nếu để mặc định `agent_api_key="changeme"`, khi deploy ứng dụng lên cloud mà quên cấu hình biến `AGENT_API_KEY`, ứng dụng vẫn khởi động bình thường. Kẻ xấu có thể nhanh chóng dùng API key mặc định `"changeme"` này để thực hiện hàng ngàn request miễn phí và làm cạn kiệt tài khoản LLM của hệ thống. Ngược lại, việc không đặt giá trị mặc định giúp app "fail fast" ném lỗi ngay khi khởi động, buộc developer phải cấu hình đúng key trước khi đưa lên môi trường sản xuất.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log mẫu: `{"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T10:00:00.000000+00:00", "user_id": "sv01", "tokens_in": 15, "tokens_out": 42, "cost_usd": 0.00002745}`

Hai việc làm được:
1. Tự động gom và filter log theo JSON field trên Datadog/CloudWatch/Railway (ví dụ: thống kê các log có `level == "error"` hoặc truy vấn `user_id == "sv01"`).
2. Tính toán tổng chi phí `cost_usd` hoặc vẽ biểu đồ latency/token theo thời gian thực nhờ các hệ thống Log Aggregator đọc và parse các field chuẩn hóa.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1020 MB |
| Multi-stage | 185 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~835MB) bao gồm các công cụ biên dịch (gcc, g++, make), header files, bộ nhớ tạm cài đặt (.cache/pip) và hệ điều hành Debian bản đầy đủ. Multi-stage build loại bỏ toàn bộ build dependencies này, chỉ giữ lại runtime binaries tinh gọn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Với Dockerfile hiện tại (`COPY requirements.txt` -> `RUN pip install` -> `COPY app ./app`), các layer cài đặt pip dependencies sẽ được lấy từ Docker cache (CACHE HIT) và Docker chỉ cần chạy lại layer copy source code (`COPY app ./app`), giúp build lại trong vài giây. Ngược lại, nếu đặt `COPY . .` lên trước `RUN pip install`, mọi thay đổi trong bất kỳ file code nào cũng làm mất cache của layer `COPY . .`, buộc Docker phải tải và chạy lại toàn bộ `pip install` từ đầu.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Nếu container chạy dưới quyền root, khi app Python có lỗ hổng (như Remote Code Execution hay Path Traversal), kẻ tấn công có thể thực thi lệnh shell trong container dưới quyền root. Từ đó, họ khai thác các lỗ hổng Container Breakout để thoát khỏi cọc cách ly và chiếm quyền root trực tiếp trên máy host. Lệnh `USER appuser` hạ quyền tiến trình xuống user thường, vô hiệu hóa khả năng can thiệp hệ thống và cắt đứt chuỗi tấn công ngay tại bước chiếm quyền root trong container.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Một người dùng có thể gửi tối đa 20 request trong 2 giây liên tiếp. Cụ thể: người dùng gửi 10 request vào 1 giây cuối của phút thứ 1 (ví dụ 10:00:59) và 10 request tiếp theo vào 1 giây đầu của phút thứ 2 (10:01:00). Cả hai đợt 10 request đều hợp lệ theo hạn mức 10/phút của phút tương ứng, nhưng làm hệ thống dồn dập gánh 20 request chỉ trong 2 giây.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Khác nhau: Rate limit giới hạn *số lượng request* trong khoảng thời gian ngắn (ví dụ: 10 req/phút). Cost guard giới hạn *tổng chi phí tài chính (USD)* tích lũy trong tháng.
- Rate limit cho qua nhưng Cost guard chặn: User gửi 1 request duy nhất trong phút nhưng prompt chứa 200,000 token khiến chi phí vượt quá ngân sách tháng 10.0$ -> Rate limit cho qua (1 < 10) nhưng Cost guard chặn (402 Payment Required).
- Cost guard cho qua nhưng Rate limit chặn: User mới bắt đầu tháng chưa tiêu đồng nào (cost = 0$) nhưng bấm refresh liên tục 15 request trong 5 giây -> Cost guard cho qua nhưng Rate limit chặn (429 Too Many Requests).

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện:
1. Redis mất kết nối trong 30 giây.
2. Endpoint `/health` kiểm tra Redis và thất bại -> trả về 503.
3. Orchestrator (Docker/K8s) tưởng rằng ứng dụng bị "treo/chết" và tự động kill & restart cả 3 container.
4. Khi 3 container mới khởi động lại, Redis vẫn chưa sẵn sàng -> `/health` tiếp tục báo lỗi -> Orchestrator lại tiếp tục kill & restart.
5. Tạo ra chuỗi lặp CrashLoopBackOff liên tục, biến một gián đoạn ngắn của Redis thành đợt ngắt kết nối kéo dài của toàn bộ hệ thống.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Nếu lưu lịch sử trong dict Python trong RAM, do Load Balancer phân phối các request ngẫu nhiên tới 3 instance khác nhau, giá trị `history_length` sẽ nhảy thất thường (ví dụ: Request 1 tới Instance A -> history_length = 0; Request 2 tới Instance B -> history_length = 0; Request 3 tới Instance A -> history_length = 2). Người dùng sẽ thấy agent "lúc nhớ lúc quên" tùy thuộc request rơi vào instance nào.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- Lỗi: `ConnectionRefusedError: [Errno 111] Connect call failed ('127.0.0.1', 6379)` khi mới deploy service lên platform cloud.
- Nguyên nhân: App đang dùng giá trị `REDIS_URL` mặc định `redis://localhost:6379/0`. Trên cloud, Redis chạy ở một instance/Add-on độc lập nên `localhost` bên trong container trỏ về chính container app chứ không phải Redis.
- Cách sửa: Khai báo lại biến môi trường `REDIS_URL` trên dashboard của platform thành URL chuẩn được cung cấp từ Redis Addon / Upstash (dạng `redis://default:password@host:port`).
