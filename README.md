# H2A 填充線面積欄位與分色

![H2A](assets/banner.svg)

[工具儲存庫](https://github.com/whos-dwg/CadLISP-H2A) · [全部工具索引](https://github.com/whos-dwg/CadLISP-Index)

把 HATCH 面積寫成欄位文字，支援單一填充、複選加總及相鄰填充分色。

| 項目 | 內容 |
| --- | --- |
| 指令 | `H2A` |
| 檔案 | [H2A.lsp](lsp/H2A.lsp) |
| 分類 | 尺寸與註解 |
| 狀態 | 來源快照，實機回歸待完成 |
| 授權 | [MIT](LICENSE)，Copyright (c) 2026 whos-dwg |

[安裝](#安裝) · [操作](#操作) · [相依與設定](#相依與設定) · [已知問題](docs/KNOWN_ISSUES.md) · [驗證紀錄](docs/VALIDATION.md)

## 安裝

以 Windows 桌面版 AutoCAD 為目標。原碼使用的 Visual LISP／ActiveX、DCL 或原生命令，需在目標 AutoCAD 版本分別確認；尚未做整包年份、LT、Mac 或其他 CAD 的相容性認證。ActiveX 的平台限制見 [Autodesk](https://help.autodesk.com/cloudhelp/2026/ENU/AutoCAD-AutoLISP/files/GUID-A0459510-CE7A-4206-9EAA-E25AAB569B20.htm)。

1. 下載並解壓縮本工具到固定位置，先開啟測試圖面。
2. 依公司環境把 `lsp` 資料夾加入需要的支援搜尋路徑與受信任位置。
3. 輸入 `APPLOAD`，載入 `H2A.lsp`；關閉視窗後輸入 `H2A`。

也可使用完整路徑單獨載入；下列路徑需依實際位置修改：

```lisp
(load "C:/CAD/CadLISP-H2A/lsp/H2A.lsp")
```

完成驗證後，可將這支 LISP 加入 APPLOAD 的 Startup Suite。請維持既定的 SECURELOAD 政策，使用受信任位置處理載入限制。[SECURELOAD 說明](https://help.autodesk.com/cloudhelp/2026/ENU/AutoCAD-Core/files/GUID-541566C6-2738-49DD-87C3-C1490E924A02.htm)。

## 操作

1. 在模型空間輸入 `H2A`，依設定提示輸入參數；mm² 轉 m² 可用乘數 0.000001。
2. 點選單一 HATCH 並指定面積文字位置；或輸入 `M` 複選加總。
3. 輸入 `C` 選取填充分色；輸入 `S` 調整參數。面積欄位更新須配合 AutoCAD 的欄位更新行為檢查。

## 相依與設定

目前文字輸出固定加入 ModelSpace。先設定面積乘數、字尾、字高與背景遮罩。

圖面影響：新增面積 MTEXT／連線；分色模式修改填充顏色。

## 行為與限制

預設乘數 1、字尾 M²、字高 1800；字尾並不代表已自動完成單位換算。分色會改變 HATCH 顏色，且會嘗試載入 acad.lin／acadiso.lin 的 HIDDEN 線型。

## 來源與授權

本工具依維護者確認為自行從零撰寫，或以 AI 協作從零開發。程式與本次文件採 [MIT 授權](LICENSE)，允許使用、修改與再散布，須保留授權及著作權聲明。詳細來源紀錄見 [provenance.json](metadata/provenance.json)。

## 回報與維護

回報時附 AutoCAD 完整版本、命令列錯誤與去識別的重現範例。修改前請閱讀 [CONTRIBUTING](CONTRIBUTING.md)；發行步驟見 [PUBLISHING](docs/PUBLISHING.md)。本工具可獨立維護、下載及發布，不依賴其他 CadLISP 工具儲存庫。
