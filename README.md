# OM Mavtar Group Khata Book - Desktop Challan & Billing Management System

A dedicated, high-performance desktop ledger application built for **OM Mavtar Group**, optimized for **Windows 10/11** and **macOS**. Developed entirely in **100% English** with complete offline-first local storage, full manual CRUD controls, advanced PDF/Excel reports, two-stage Recycle Bin security, and automated CI/CD for Windows setup `.exe` distribution.

---

## 1. Key Features Overview

| Feature | Description |
| :--- | :--- |
| **Manual Data Control** | User manually creates, edits, soft-deletes, views, and filters all challan entries and parties. |
| **B2B Challan Fields** | Date, Challan No., Party, Challan Amount, Final Amount, GST Bill No., GST Amount, Payment Option (Cash / Cheque). |
| **Unpaid Cash Warning** | Unpaid / Pending cash entries are automatically highlighted in **light-red / warning tone** (`⚠️ UNPAID CASH`). |
| **Cheque Tracking** | Cheque Date, Cheque No., Issuing Bank Name, Cheque Amount, Status (Pending, Cleared, Bounced). |
| **Parties Directory** | Dedicated party management with instant autocomplete search during challan creation. |
| **PDF & Excel Reports** | Filter by Single/Multiple Parties, Monthly/Period ranges, Ascending/Descending date sorting. |
| **Recycle Bin (Trash)** | Deleted challans and parties move to the Recycle Bin first. Restore anytime or permanently delete forever. |
| **Database Backup & Restore** | 100% offline JSON export and restore from the Settings screen. |
| **Windows Setup Installer (.exe)** | One-click `.exe` installer with desktop shortcuts and clean Windows Programs & Features uninstaller. |
| **GitHub Actions CI/CD** | Automated cloud build that compiles the release `.exe` setup file downloadable from GitHub. |

---

## 2. Core Field Specifications

Every challan record in OM Mavtar Group Khata Book contains:

1. **Date** (`date`): Displayed prominently on the table and card; selectable via date picker (defaults to current date).
2. **Challan No.** (`challanNo`): Unique challan identifier (e.g. `CH-2026-101`).
3. **Party** (`partyName` / `partyId`): Selected through an instant searchable dropdown / autocomplete populated from pre-registered parties.
4. **Challan Amount** (`challanAmount`): Base/gross amount of the delivery challan.
5. **Final Amount** (`finalAmount`): Final settlement amount payable/receivable.
6. **GST Bill No.** (`gstBillNo`): Tax invoice number corresponding to the challan.
7. **GST Amount** (`gstAmount`): GST component amount.
8. **Payment Option**:
   - **Cash**:
     - Status: `Paid` or `Unpaid / Pending`.
     - **Warning Highlight**: When marked unpaid, the entire row/card is shaded in light red with a red badge: `⚠️ UNPAID CASH`.
   - **Cheque**:
     - *Cheque Date*: Issue date.
     - *Cheque No.*: 6-digit cheque identifier.
     - *Bank Name*: Issuing bank (e.g., SBI, HDFC, ICICI, Bank of Baroda).
     - *Cheque Amount*: Value written on the cheque.
     - *Cheque Status*: `Pending`, `Cleared`, or `Bounced`.
9. **Creation Timestamp** (`createdAt`): System timestamp automatically recorded in the background.

---

## 3. Recycle Bin (Trash / Soft Delete)

To prevent accidental data loss:
- When a user deletes a challan or party from the main view, it is **moved to the Recycle Bin** (marked `isDeleted: true` with a timestamp).
- A quick **Undo** snackbar allows immediate reversal.
- In the **Recycle Bin** tab:
  - **Restore**: Returns the record back into the active ledger / party directory immediately.
  - **Delete Permanently**: Permanently erases the record from the database. Once permanently purged, it cannot be recovered from any archive.
  - **Empty Recycle Bin**: Purges all soft-deleted records across both challans and parties with a single confirmation.

---

## 4. Reports & Data Export (PDF & Excel)

Generate reports tailored to your exact criteria:

### PDF Reports:
- **Print / Preview**: Landscape layout with OM Mavtar Group branding, active filter summary, summary KPI cards, styled data tables, and page counters.
- **Save PDF**: Directly writes formatted `.pdf` to your system's Documents folder.

### Excel (.xlsx) Reports:
- Generates Microsoft Excel workbooks with formatted headers, dates, numbers, and calculated sum totals.

### Filter Scopes:
- **Party Selection**:
  - All Parties
  - Single Specific Party
  - Multiple Selected Parties (interactive multi-select)
- **Time Periods**:
  - Specific Month (Monthly Ledger, e.g. November 2026)
  - All Time Data
  - Current Filtered View
  - Custom Date Range
- **Date Sorting**:
  - **Ascending**: Oldest records first.
  - **Descending**: Newest records first.

---

## 5. Windows 10/11 Setup Installer (.exe) & GitHub Actions

### Automatic Cloud Builds via GitHub Actions
A complete GitHub Actions workflow (`.github/workflows/build_windows_exe.yml`) is set up to automatically build the Windows installer whenever you push to GitHub or trigger it manually:

1. **Push your code to GitHub**:
   ```bash
   git add .
   git commit -m "Add Recycle Bin, Windows installer, and CI/CD workflow"
   git push origin main
   ```
2. **Go to GitHub**:
   - Open your repository on GitHub in a web browser.
   - Click on the **Actions** tab at the top.
   - Select the workflow: **Build Windows Desktop Setup Installer (.exe)**.
   - Click **Run workflow** (or watch the push trigger automatically).
3. **Download the `.exe` Setup File**:
   - When the workflow completes (green checkmark), click on the run.
   - Scroll down to the **Artifacts** section at the bottom.
   - Click **OmMavtarKhataBook-Windows-Installer** to download the zip.
   - Extract the zip to get:
     - `OmMavtarKhataBook_Setup.exe` (Standalone Windows Installer)
     - `OmMavtarKhataBook_Windows_Portable_v2.0.0.zip` (Portable Version)
4. **Distribute & Run**:
   - Send `OmMavtarKhataBook_Setup.exe` directly to anyone on Windows 10/11.
   - Double-click to run the setup wizard.
   - The installer places the app in `Program Files`, adds Start Menu and Desktop shortcuts, and registers an official uninstaller in **Windows Settings > Installed Apps / Add or Remove Programs**.

### Local Windows Compilation (Optional, on a Windows PC):
```powershell
flutter build windows --release
iscc windows\installer\inno_setup.iss
```

---

## 6. How to Run Locally

### macOS Desktop:
```bash
flutter pub get
flutter run -d macos
```

### Windows 10 / 11 Desktop:
```powershell
flutter pub get
flutter run -d windows
```

### Run Tests:
```bash
flutter test
```

### Static Analysis:
```bash
flutter analyze
```

---

## 7. Project Architecture

```
om_khatabook/
├── .github/
│   └── workflows/
│       └── build_windows_exe.yml      # GitHub Actions CI/CD for Windows .exe
├── assets/
│   └── logo/
│       ├── app_logo.png              # Primary OM Mavtar Group branding logo
│       └── app_logo_white.png        # Transparent/light variant logo
├── lib/
│   ├── main.dart                      # App entry point with Provider scope
│   ├── models/
│   │   ├── challan_entry.dart         # Challan model with soft-delete & warning flags
│   │   └── party.dart                 # Party directory model with soft-delete
│   ├── providers/
│   │   └── challan_provider.dart      # Business logic, filters, sorting, Recycle Bin
│   ├── services/
│   │   ├── export_service.dart        # PDF & Excel (.xlsx) generator
│   │   └── storage_service.dart       # Local persistence & JSON backup/restore
│   ├── theme/
│   │   └── app_theme.dart             # Corporate branding theme (Light & Dark)
│   ├── views/
│   │   ├── challan_list_view.dart     # Main Challan Ledger with filters & warning highlight
│   │   ├── main_layout.dart           # Desktop sidebar layout with app logo & badges
│   │   ├── parties_view.dart          # Party directory management
│   │   ├── recycle_bin_view.dart      # Recycle Bin with Restore & Permanent Delete
│   │   ├── settings_view.dart         # Backup, restore & database metrics
│   │   └── summary_reports_view.dart  # Financial KPI summary & export launcher
│   └── widgets/
│       ├── add_edit_challan_dialog.dart # Form dialog with party autocomplete
│       ├── add_edit_party_dialog.dart   # Party creation/editing dialog
│       └── export_report_dialog.dart    # Report filter & export wizard
├── test/
│   ├── recycle_bin_test.dart          # Unit tests for soft-delete & permanent purge
│   └── widget_test.dart               # Smoke tests for app UI
└── windows/
    ├── runner/
    │   └── resources/
    │       └── app_icon.ico           # Windows multi-resolution icon
    └── installer/
        └── inno_setup.iss             # Inno Setup Windows installer compiler script
```
