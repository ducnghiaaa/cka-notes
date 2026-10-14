# Ngày 5 — Pod, imperative, output, kubeconfig (13/10/2026)

**Thời gian:** dự kiến 4h · thực tế _h  
**Tự đánh giá:** 3.5/5 — nhiều cú pháp mới cùng lúc, thấy ngợp nhưng đã cố gắng.  
**Kết quả:** làm đến hết phần 3.5. Thử thách 3.6, drill xen kẽ và đóng buổi **dời sang Ngày 6**.

## Đã làm

| Phần | Kết quả |
| --- | --- |
| Ôn: Mistake log + flashcard | Xong |
| Docs: quick reference, JSONPath, labels, kubeconfig | Xong |
| 3.1 Tạo object imperative (`k run/create/expose`, `$do`) | Xong |
| 3.2 Label & selector | Xong, nhưng chưa rõ liên hệ selector ↔ endpoint |
| 3.3 `k explain` | Xong |
| 3.4 jsonpath / custom-columns / `--sort-by` | Làm được, **còn yếu** |
| 3.5 Kubeconfig & context | Xong |

## Selector ↔ endpoint

Service không biết pod theo tên; nó giữ **selector**. Controller liên tục tìm pod có label khớp và Ready → ghi IP vào **EndpointSlice** → traffic tới Service đi đến các IP đó.

- Pod đổi label → bị gạch khỏi EndpointSlice.
- Selector gõ sai → EndpointSlice **rỗng** → gọi Service timeout, dù pod vẫn Running.
- Debug: `k get endpointslice -l kubernetes.io/service-name=<svc>` rỗng → so `k get svc -o wide` (SELECTOR) với `k get pod --show-labels`.

## jsonpath, custom-columns, sort-by = địa chỉ trong cây JSON

| Ký hiệu | Nghĩa |
| --- | --- |
| `.a.b` | đi vào trong |
| `[0]` / `[*]` | phần tử đầu / mọi phần tử của danh sách |
| `.items[*]` | gốc khi `get` nhiều object — **chỉ dùng trong jsonpath** |

| Công cụ | Dùng khi |
| --- | --- |
| `-o jsonpath` | lấy giá trị để ghi file |
| `-o custom-columns=TÊN:địa-chỉ` | cần bảng (không có `.items`) |
| `--sort-by=địa-chỉ` | sắp xếp (không có `.items`) |

Bậc thang (làm lại ở khối Ôn Ngày 6):

```bash
k get pod p2 -o jsonpath='{.metadata.name}'
k get pod p2 -o jsonpath='{.spec.containers[0].image}'
k get pod -o jsonpath='{.items[*].metadata.name}'
k get pod -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
k get pod -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'
k get pod -o custom-columns=NAME:.metadata.name,IP:.status.podIP
k get pod -o custom-columns=NAME:.metadata.name,IP:.status.podIP --sort-by=.metadata.name
```

Dự phòng trong phòng thi: quá 2 phút chưa viết xong jsonpath → `-o wide`/`-o name`, đọc rồi gõ tay vào file (đề chấm nội dung file).

## Bài học về nhịp học

Một buổi dồn 5 cú pháp mới (jsonpath, custom-columns, sort-by, selector, kubeconfig) là quá nhiều. Từ Ngày 6: **tối đa ~3 cú pháp mới mỗi buổi**, còn lại là làm lại.

## Ngày mai (Ngày 6 — T4 14/10)

- Ôn: demo Service ↔ endpoint, bậc thang jsonpath 1–7.
- Mới: Deployment, rollout, break-fix pod.
- Drill: thử thách 3.6 của Ngày 5.
