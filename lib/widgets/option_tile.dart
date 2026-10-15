import 'package:flutter/material.dart';

import '../models/option.dart';

class OptionTile extends StatelessWidget {
  final Option option;
  final bool selected;
  final bool isMultipleChoice;
  final bool enabled;
  final VoidCallback onTap;

  const OptionTile({
    super.key,
    required this.option,
    required this.selected,
    required this.isMultipleChoice,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = isMultipleChoice
        ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
        : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: selected ? 1 : 0,
      color: selected ? colorScheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(radius: 16, child: Text(option.optionKey)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                color: selected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}