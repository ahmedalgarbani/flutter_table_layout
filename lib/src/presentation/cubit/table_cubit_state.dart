import '../../domain/models/column_definition.dart';
import '../../domain/models/table_snapshot.dart';
import '../../domain/models/table_state_model.dart';

/// Identifies a row across data updates, e.g. its database id.
///
/// Selection and expanded rows are matched by this key instead of `==`, so
/// they survive new item instances (immutable updates, server reloads).
typedef RowKeyBuilder<T> = Object? Function(T item);

/// Computes the footer value of a column from the rows it summarizes.
typedef TableAggregator<T> = Object? Function(List<T> rows);

/// Sealed class representing the reactive state of the table layout.
/// Designed according to Dart 3 specifications (exhaustiveness, no code generation).
sealed class TableCubitState<T> {
  const TableCubitState();
}

/// The initial state before items are set.
class TableInitial<T> extends TableCubitState<T> {
  const TableInitial();
}

/// The processing state, e.g. when filtering or sorting large datasets.
class TableLoading<T> extends TableCubitState<T> {
  const TableLoading();
}

/// The active state containing data, pagination slices, and selection models.
class TableLoaded<T> extends TableCubitState<T> {
  /// The full list of source items.
  final List<T> originalItems;

  /// The items after applying search, dates, and custom filters.
  final List<T> filteredAndSortedItems;

  /// The subset of items for the active page.
  final List<T> paginatedItems;

  /// Total item count post-filtering (used to calculate pages).
  final int totalCount;

  /// Number of pages (always at least 1).
  final int totalPages;

  /// Current search, sort, and pagination state.
  final TableStateModel tableState;

  /// Selected items (a subset of [originalItems]).
  final List<T> selectedItems;

  /// IDs of columns hidden by the user.
  final List<String> hiddenColumnIds;

  /// Rows whose details (`expandedRowBuilder`) are currently open.
  final List<T> expandedItems;

  /// Widths set by the user by dragging a header edge (column id → px).
  final Map<String, double> columnWidths;

  /// Column ids in the order chosen by the user (drag & drop). Columns not
  /// listed keep their declaration order after the listed ones.
  final List<String> columnOrder;

  /// Frozen positions changed at runtime (column id → pin).
  final Map<String, ColumnPin> columnPins;

  /// Keys of collapsed groups (see `TableStateModel.groupByColumnId`).
  final Set<String> collapsedGroups;

  /// `true` while a server-side data source request is in flight.
  final bool isFetching;

  /// Footer totals of the columns that declare an aggregate (column id →
  /// value), over every filtered row (the current page in server mode,
  /// unless the server returns its own totals).
  final Map<String, Object?> aggregates;

  /// Row identity used for [selectedItems] / [expandedItems]. `null` uses the
  /// items themselves (`==`).
  final RowKeyBuilder<T>? rowKey;

  const TableLoaded({
    required this.originalItems,
    required this.filteredAndSortedItems,
    required this.paginatedItems,
    required this.totalCount,
    required this.tableState,
    int? totalPages,
    this.selectedItems = const [],
    this.hiddenColumnIds = const [],
    this.expandedItems = const [],
    this.columnWidths = const {},
    this.columnOrder = const [],
    this.columnPins = const {},
    this.collapsedGroups = const {},
    this.isFetching = false,
    this.aggregates = const {},
    this.rowKey,
  }) : totalPages = totalPages ?? 1;

  /// Identity of [item] (see [rowKey]).
  Object? keyOf(T item) {
    final key = rowKey;
    return key == null ? item : key(item);
  }

  /// Keys of the selected rows. Build it once per frame and test rows with
  /// `selectedKeys.contains(keyOf(item))`.
  Set<Object?> get selectedKeys => {for (final s in selectedItems) keyOf(s)};

  /// Keys of the expanded rows.
  Set<Object?> get expandedKeys => {for (final e in expandedItems) keyOf(e)};

  /// Whether [item] is selected. For many rows prefer [selectedKeys].
  bool isSelected(T item) {
    final key = keyOf(item);
    return selectedItems.any((s) => keyOf(s) == key);
  }

  /// Whether [item]'s details are open. For many rows prefer [expandedKeys].
  bool isExpanded(T item) {
    final key = keyOf(item);
    return expandedItems.any((e) => keyOf(e) == key);
  }

  /// The current query and column layout, e.g. to persist them.
  TableSnapshot get snapshot => TableSnapshot(
    tableState: tableState,
    hiddenColumnIds: hiddenColumnIds,
    columnWidths: columnWidths,
    columnOrder: columnOrder,
    columnPins: columnPins,
  );

  /// Effective frozen position of [column] (runtime pin or declared pin).
  ColumnPin pinOf(ColumnDefinition column) =>
      columnPins[column.id] ?? column.pin;

  /// Visible columns in display order: user order (drag & drop) first, then
  /// grouped as start-pinned, unpinned, end-pinned.
  List<C> arrange<C>(List<C> columns, ColumnDefinition Function(C) def) {
    final hidden = hiddenColumnIds.toSet();
    final visible = columns.where((c) => !hidden.contains(def(c).id)).toList();
    if (columnOrder.isNotEmpty) {
      final rank = {
        for (var i = 0; i < columnOrder.length; i++) columnOrder[i]: i,
      };
      final declared = {for (var i = 0; i < visible.length; i++) visible[i]: i};
      visible.sort((a, b) {
        final ra = rank[def(a).id] ?? (columnOrder.length + declared[a]!);
        final rb = rank[def(b).id] ?? (columnOrder.length + declared[b]!);
        return ra.compareTo(rb);
      });
    }
    return [
      ...visible.where((c) => pinOf(def(c)) == ColumnPin.start),
      ...visible.where((c) => pinOf(def(c)) == ColumnPin.none),
      ...visible.where((c) => pinOf(def(c)) == ColumnPin.end),
    ];
  }

  /// Whether every filtered row is selected.
  bool get isAllSelected => selectAllValue == true;

  /// `true` = all filtered rows selected, `false` = none, `null` = some.
  bool? get selectAllValue {
    if (selectedItems.isEmpty || filteredAndSortedItems.isEmpty) return false;
    final selected = selectedKeys;
    final count = filteredAndSortedItems
        .where((i) => selected.contains(keyOf(i)))
        .length;
    if (count == 0) return false;
    if (count == filteredAndSortedItems.length) return true;
    return null;
  }

  /// Copy helper to transition states.
  TableLoaded<T> copyWith({
    List<T>? originalItems,
    List<T>? filteredAndSortedItems,
    List<T>? paginatedItems,
    int? totalCount,
    int? totalPages,
    TableStateModel? tableState,
    List<T>? selectedItems,
    List<String>? hiddenColumnIds,
    List<T>? expandedItems,
    Map<String, double>? columnWidths,
    List<String>? columnOrder,
    Map<String, ColumnPin>? columnPins,
    Set<String>? collapsedGroups,
    bool? isFetching,
    Map<String, Object?>? aggregates,
  }) {
    return TableLoaded<T>(
      originalItems: originalItems ?? this.originalItems,
      filteredAndSortedItems:
          filteredAndSortedItems ?? this.filteredAndSortedItems,
      paginatedItems: paginatedItems ?? this.paginatedItems,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      tableState: tableState ?? this.tableState,
      selectedItems: selectedItems ?? this.selectedItems,
      hiddenColumnIds: hiddenColumnIds ?? this.hiddenColumnIds,
      expandedItems: expandedItems ?? this.expandedItems,
      columnWidths: columnWidths ?? this.columnWidths,
      columnOrder: columnOrder ?? this.columnOrder,
      columnPins: columnPins ?? this.columnPins,
      collapsedGroups: collapsedGroups ?? this.collapsedGroups,
      isFetching: isFetching ?? this.isFetching,
      aggregates: aggregates ?? this.aggregates,
      rowKey: rowKey,
    );
  }
}

/// State representation when an operation throws an exception
/// (e.g. a `valueProvider` or `customFilterMatcher` threw).
class TableError<T> extends TableCubitState<T> {
  final String errorMessage;
  final Object? error;
  final StackTrace? stackTrace;

  const TableError(this.errorMessage, {this.error, this.stackTrace});
}
