# Changelog

## 0.0.2

* **Dynamic Form Generator**: 
  * Implemented `DynamicFormField` schemas with automatic field type detection (inferred from column properties like name patterns for dates, numbers, booleans, and dropdown lists).
  * Created `DynamicForm` and `DynamicFormDialog` with fully-validated inputs, customized actions, and submit callback events.
* **Premium Adaptive Themes**:
  * Added `AdaptiveTableTheme.glassmorphic` featuring iOS-like real-time backdrop blur filter overlay (`BackdropFilter`) and translucency.
  * Added `AdaptiveTableTheme.gradient` implementing styling sweeps across headers and footers.
  * Added `AdaptiveTableTheme.cozy` supporting soft shadows and expanded spacing.
* **CRUD Action Handlers & Settings**:
  * Integrated interactive styling picker inside the AppBar settings.
  * Replaced static action buttons with CRUD dialog triggers utilizing the dynamic forms generator.
* **Validation & Testing**:
  * Added comprehensive unit and widget tests covering type detection, validation logic, and form state submissions.

## 0.0.1

* Initial release of the adaptive data table layout.
* Responsive layouts automatically adapting between desktop data grids and collapsable mobile cards.
* Localized global searching, date-range filtering, and pagination support.
* Multi-currency aggregate bottom banner summary builder.
* Integrated Excel, Word, PDF, and system printing exporters with shaped Arabic font support.
