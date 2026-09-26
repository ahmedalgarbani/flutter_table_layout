/// Adaptive, responsive data tables for Flutter: desktop grid + mobile cards,
/// search, date & custom filters, sorting, pagination, selection, summaries,
/// Excel / Word / PDF export, printing, dynamic forms, themes, and RTL.
library;

// Re-exported so custom filters / toolbar widgets can use
// `context.read<TableCubit<T>>()` or `BlocBuilder` without adding flutter_bloc.
export 'package:flutter_bloc/flutter_bloc.dart'
    show
        BlocBuilder,
        BlocConsumer,
        BlocListener,
        BlocSelector,
        ReadContext,
        SelectContext,
        WatchContext;

// Core
export 'src/core/labels.dart';
export 'src/core/theme.dart';
export 'src/core/utils/file_saver.dart';

// Data
export 'src/data/exporters/excel_exporter.dart';
export 'src/data/exporters/export_utils.dart';
export 'src/data/exporters/pdf_exporter.dart';
export 'src/data/exporters/table_export_options.dart';
export 'src/data/exporters/word_exporter.dart';

// Domain
export 'src/domain/datasource/table_data_source.dart';
export 'src/domain/models/column_definition.dart';
export 'src/domain/models/column_filter.dart';
export 'src/domain/models/table_state_model.dart';
export 'src/domain/usecases/filter_items_usecase.dart';

// Presentation
export 'src/presentation/controller/adaptive_table_controller.dart';
export 'src/presentation/cubit/table_cubit.dart';
export 'src/presentation/cubit/table_cubit_state.dart';
export 'src/presentation/widgets/adaptive_table_layout.dart';
export 'src/presentation/widgets/date_range/date_range_panel.dart';
export 'src/presentation/widgets/date_range/date_range_preset.dart';
export 'src/presentation/widgets/dynamic_form.dart';
export 'src/presentation/widgets/grid/cell_editor.dart';
export 'src/presentation/widgets/grid/table_entries.dart' show TableGroupInfo;
