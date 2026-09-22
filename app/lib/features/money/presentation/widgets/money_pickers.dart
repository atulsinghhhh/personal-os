import 'package:flutter/material.dart';

import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import 'money_ui.dart';

/// Bottom-sheet pickers shared by Add expense/income and Transaction detail.

Future<FinancialAccount?> showAccountPicker(
  BuildContext context, {
  required List<FinancialAccount> accounts,
}) {
  return showAppBottomSheet<FinancialAccount>(
    context: context,
    title: 'Choose account',
    builder: (BuildContext sheetContext) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final FinancialAccount account in accounts)
            AppListRow(
              title: account.name,
              subtitle:
                  '${accountTypeLabel(account.type)} · ${account.openingBalance.currency}',
              onTap: () => Navigator.of(sheetContext).pop(account),
            ),
        ],
      );
    },
  );
}

Future<TransactionCategory?> showCategoryPicker(
  BuildContext context, {
  required List<TransactionCategory> categories,
}) {
  return showAppBottomSheet<TransactionCategory>(
    context: context,
    title: 'Choose category',
    builder: (BuildContext sheetContext) {
      return SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.5,
        child: ListView(
          children: <Widget>[
            for (final TransactionCategory category in categories)
              AppListRow(
                title: category.name,
                dense: true,
                onTap: () => Navigator.of(sheetContext).pop(category),
              ),
          ],
        ),
      );
    },
  );
}

/// Result wrapper so "cleared the link" (project == null) is distinguishable
/// from "dismissed the sheet" (null result).
class ProjectPick {
  const ProjectPick(this.project);

  final Project? project;
}

Future<ProjectPick?> showProjectPicker(
  BuildContext context, {
  required List<Project> projects,
  bool allowClear = false,
}) {
  return showAppBottomSheet<ProjectPick>(
    context: context,
    title: 'Link to project',
    builder: (BuildContext sheetContext) {
      return SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.5,
        child: ListView(
          children: <Widget>[
            if (allowClear)
              AppListRow(
                title: 'No project',
                dense: true,
                leading: const Icon(Icons.link_off),
                onTap: () =>
                    Navigator.of(sheetContext).pop(const ProjectPick(null)),
              ),
            for (final Project project in projects)
              AppListRow(
                title: project.title,
                dense: true,
                leading: const Icon(Icons.folder_outlined),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ProjectPick(project)),
              ),
          ],
        ),
      );
    },
  );
}
