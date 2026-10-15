import 'package:flutter/material.dart';

import '../models/question.dart';

class AnswerResultPanel extends StatelessWidget {
  final bool isCorrect;
  final Question question;
  final String selectedAnswer;

  const AnswerResultPanel({
    super.key,
    required this.isCorrect,
    required this.question,
    required this.selectedAnswer,
  });

  String _answerText(String answer) {
    if (answer.isEmpty) {
      return '未作答';
    }

    final optionMap = <String, String>{
      for (final option in question.options) option.optionKey: option.content,
    };

    final labels = answer.split('').map((String key) {
      final content = optionMap[key] ?? '';
      return content.isEmpty ? key : '$key. $content';
    }).toList();

    return labels.join('；');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isCorrect
        ? colorScheme.primaryContainer
        : colorScheme.errorContainer;
    final foreground = isCorrect
        ? colorScheme.onPrimaryContainer
        : colorScheme.onErrorContainer;

    return Card(
      color: background,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                    color: foreground),
                const SizedBox(width: 8),
                Text(
                  isCorrect ? '回答正确' : '回答错误',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '你的答案：${_answerText(selectedAnswer)}',
              style: TextStyle(color: foreground),
            ),
            const SizedBox(height: 6),
            Text(
              '正确答案：${_answerText(question.correctAnswer)}',
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Divider(color: foreground.withAlpha(80)),
            const SizedBox(height: 8),
            Text(
              '解析',
              style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              question.explanation.isEmpty ? '暂无解析' : question.explanation,
              style: TextStyle(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}