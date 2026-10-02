# 05. UI / UX Guidelines & Design System

## 1. Brand Color System (Material 3)

The design system uses a refined industrial palette tailored for **Saark Exploration Private Limited**.

### Color Tokens:
- **Primary Accent (Saark Orange)**: `#F97316` (Used for active navigation, primary buttons, state highlights)
- **Primary Dark Accent**: `#C2410C`
- **Primary Light Container**: `#FFEDD5`
- **Dark Mode Background**: `#0F1115`
- **Dark Mode Surface / Cards**: `#181B21`
- **Dark Mode Borders**: `#2A2E37`
- **Light Mode Background**: `#F7F8FA`
- **Light Mode Surface / Cards**: `#FFFFFF`
- **Light Mode Borders**: `#E2E8F0`

---

## 2. Layout Adaptability Matrix

| Component / Screen | Mobile (< 600px) | Tablet (600px - 1024px) | Desktop / Web (> 1024px) |
|---|---|---|---|
| **Navigation** | Bottom Navigation Bar + Drawer | Navigation Rail | Collapsible Left Sidebar |
| **Top Header** | App Bar with Quick Actions | Header with Search & Year Selector | Header with Global Search, FY, Notifications, User |
| **Data Tables** | Cards / Compact List items | Two-Column Layout | Full Multi-Column Data Table with Pagination |
| **Forms** | Single Column Vertical | Two Column Grid | Multi-Column Modal / Tabbed Form |
| **Action Panels** | Bottom Sheets | Side Drawers | Dialog Modals or Embedded Panels |

---

## 3. Standard UI Components Blueprint
- `AppButton`: Supports `filled`, `outlined`, `text`, `icon` variants with built-in loading indicator state.
- `AppTextField`: Clean outline borders, error feedback text, clear button, custom icons.
- `AppDataTable`: Sticky header, column sort arrows, checkbox select, search filter, page selector.
- `AppStatusBadge`: Color-coded chip pill (`NEW` -> Blue, `QUALIFIED` -> Purple, `APPROVED` -> Green, `REJECTED` -> Red).
- `AppEmptyState`: Modern illustration placeholder for zero records.
