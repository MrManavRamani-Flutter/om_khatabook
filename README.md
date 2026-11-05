# OM Mavtar Group Khata Book - Challan & Billing Management System

## 1. Analysis of Previous System & Transition

### Previous System Analysis
- The previous implementation was a generic two-column cash ledger (`You Gave` / `You Got`) inspired by consumer apps (KhataBook/OkCredit).
- It used language mixing (Hindi/Gujarati/English such as "Lene Hai", "Dene Hai", "Rojmel").
- It lacked commercial B2B invoicing fields such as **Challan Number**, **GST Bill Number**, **GST Amount**, **Final Amount**, and dual-mode **Cash/Cheque** settlement tracking.

### Transition & Current Dedicated System
- The entire application has now been restructured into a dedicated, professional **Challan & Billing Ledger Management System** in **100% English**.
- **Every entry is manually controlled** with full **Add**, **Edit**, **Delete**, and **View** capabilities.
- Pre-registered **Party directory** with instant autocomplete search inside the entry form.
- Direct status highlighting: **Unpaid Cash entries are highlighted in warning light-red** across the entire row/card.
- Detailed **Cheque tracking** with Cheque Date, Cheque Number, Bank Name, and Clearance Status.

---

## 2. Core Field Specifications

Every record contains the following strictly managed fields:
1. **Date** (`date`): Displayed prominently on the table/card, editable via DatePicker (defaults to current date).
2. **Challan No.** (`challanNo`): Unique challan identifier (e.g. `CH-2024-001`).
3. **Party** (`partyName` / `partyId`): Selected via fast searchable autocomplete from pre-added parties.
4. **Challan Amount** (`challanAmount`): Original challan gross value.
5. **Final Amount** (`finalAmount`): Final payable/receivable amount after adjustments.
6. **GST Bill No.** (`gstBillNo`): Associated Tax/GST invoice number.
7. **GST Amount** (`gstAmount`): GST tax value.
8. **Payment Option**:
   - **Cash**:
     - *Payment Status*: Paid or Unpaid (Pending).
     - **Warning Highlight**: If Cash payment is **Unpaid / Pending**, the entire record is highlighted in a distinct **light-red / warning tone** with an alert badge.
   - **Cheque**:
     - *Cheque Date*: Date written on the cheque.
     - *Cheque No.*: 6-digit cheque number.
     - *Bank Name*: Name of issuing bank (e.g., HDFC, SBI, ICICI).
     - *Cheque Amount*: Amount specified on the cheque.
     - *Cheque Status*: Pending, Cleared, or Bounced.
9. **Creation Timestamp** (`createdAt`): Hidden from the input form, automatically stamped in the background with `DateTime.now()`.

---

## 3. Desktop UI & Features

- **Challan Ledger Grid**: Fast desktop table with sorting, search, and warning highlights.
- **Advanced Filtering**:
  - Filter by Payment Option (All / Cash / Cheque).
  - Filter by Status (All / Paid / Unpaid Warning / Cleared / Bounced).
  - Filter by Party.
  - Filter by Date Range (Today / This Week / This Month / Custom Range).
- **Search**: Instant multi-field search across Challan No., GST Bill No., Party Name, Cheque No., and Bank Name.
- **Parties Directory**: Pre-add, edit, and delete parties with phone, address, and GSTIN.
- **Form Validations**: Comprehensive client-side validations on required fields, amount formats, and cheque details.
- **100% Offline Storage**: Data saved locally on macOS and Windows with JSON export/import for safety.

---

## 4. How to Run on Desktop

### macOS
```bash
flutter run -d macos
flutter build macos
```

### Windows 10 / 11
```bash
flutter run -d windows
flutter build windows
```
