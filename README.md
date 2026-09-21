# 3105x — Free Fire Patch Manager

[![Build IPA](https://github.com/xuantrun/tesst111/actions/workflows/build.yml/badge.svg)](https://github.com/xuantrun/tesst111/actions/workflows/build.yml)

> **📥 Tải IPA mới nhất tại [Releases](https://github.com/xuantrun/tesst111/releases/latest)**

---

Dự án **3105x** được xây dựng dựa trên nền tảng mã nguồn mở [YangJiiii/3105](https://github.com/YangJiiii/3105).  
Toàn bộ lớp backend sandbox (`ContainerStore`, `PatchTransaction`, `KernelExploit`) giữ nguyên từ 3105 gốc.  
UI được thiết kế lại hoàn toàn theo phong cách FFXC Dark Menu.

---

## Cài đặt

1. Tải file `3105x.ipa` từ tab **[Releases](https://github.com/xuantrun/tesst111/releases/latest)**
2. Cài qua **ESign** hoặc **TrollStore** (không cần jailbreak, cần chứng chỉ Enterprise)
3. Mở app → Chọn game → Bật tính năng mong muốn → Nhấn **INJECT**
4. Tắt / khởi động lại Free Fire để kích hoạt

---

## Tính năng (k0 - k23)

| Key | Tên | Mô tả |
|-----|-----|-------|
| k0 | Wallhack | Nhìn xuyên tường |
| k1 | Aimbot | Auto aim assist |
| k2 | No Recoil | Không giật súng |
| k3 | Speed Boost | Tăng tốc di chuyển |
| k4 | No Spread | Đạn không tản |
| k5 | Rapid Fire | Bắn nhanh hơn |
| k6 | Long Range | Tăng tầm bắn |
| k7 | Anti-Ban Shield | Ẩn chữ ký |
| k8 | Auto Headshot | Ưu tiên headbox |
| k9 | Item Radar | Highlight loot trên map |
| k10 | Drone View | Camera từ trên cao |
| k11 | Fast Loot | Nhặt đồ tức thì |
| k12 | Silent Aim | Bắn trúng không cần nhắm giữa |
| k13 | No Flash | Miễn flash |
| k14 | No Smoke | Nhìn xuyên smoke |
| k15 | High Jump | Nhảy cao hơn |
| k16 | Fast Revive | Hồi sinh đồng đội tức thì |
| k17 | Unlimited Ammo | Không cần reload |
| k18 | Fly Hack | Bay tự do |
| k19 | Vehicle Speed | Tăng tốc xe |
| k20 | Gloo Wall Spam | Đặt tường tức thì |
| k21 | ESP Box | Khung kẻ địch |
| k22 | Health Bar ESP | Hiện HP trên đầu |
| k23 | Distance ESP | Hiện khoảng cách (m) |

---

## Cách hoạt động

```
Toggle ON/OFF (UI)
    │
    ▼  ffxc.controls.v3.[id]  →  UserDefaults
    ▼
[INJECT]
    ├── Quét /var/mobile/Containers/Data/Application/
    ├── Đọc .com.apple.mobile_container_manager.metadata.plist
    ├── Tìm container của com.dts.freefiremax / com.dts.freefireth
    ├── Copy Assembly-CSharp-patch.bytes → Documents/
    └── Write localConfig.json → Documents/

[CLEAR]
    └── Xóa patch files → game về trạng thái gốc
```

---

## Credits

- Base framework: [YangJiiii/3105](https://github.com/YangJiiii/3105) (GPL-3.0)
- IFix patch engine: Tencent InjectFix
