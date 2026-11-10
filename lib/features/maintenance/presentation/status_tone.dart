import '../../../shared/widgets/status_badge.dart';
import '../domain/maintenance_calculator.dart';

extension ItemStatusTone on ItemStatus {
  BadgeTone get tone => switch (this) {
        ItemStatus.ok => BadgeTone.ok,
        ItemStatus.warning => BadgeTone.warning,
        ItemStatus.danger => BadgeTone.danger,
        ItemStatus.unknown => BadgeTone.neutral,
      };
}

/// 1 vencido / 2 vencidos
String plural(int n, String singular, String pluralForm) => '$n ${n == 1 ? singular : pluralForm}';
