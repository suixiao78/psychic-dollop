import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/practice_mode.dart';
import '../models/question.dart';
import '../models/quiz_arguments.dart';
import '../providers/practice_provider.dart';
import '../widgets/answer_result_panel.dart';
import '../widgets/empty_view.dart';
import '../widgets/option_tile.dart';

class QuizPage extends StatefulWidget {
  final QuizArguments arguments;

  const QuizPage({
    super.key,
    required this.arguments,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _startPractice();
    });
  }

  void _startPractice() {
    final provider = context.read<PracticeProvider>();
    provider.reset();
    provider.startPractice(
      mode: widget.arguments.mode,
      examLevel: widget.arguments.examLevel,
      subjectId: widget.arguments.subjectId,
      chapterId: widget.arguments.chapterId,
      count: widget.arguments.count,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PracticeProvider>(
      builder: (context, provider, child) {
        final question = provider.currentQuestion;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.arguments.title),
            actions: [
              IconButton(
                tooltip: provider.isFavorite ? '取消收藏' : '收藏',
                onPressed: question == null
                    ? null
                    : () {
                        provider.toggleFavorite();
                      },
                icon: Icon(
                  provider.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
              ),
            ],
          ),
          body: _buildBody(context, provider),
          bottomNavigationBar:
              question == null ? null : _buildBottomBar(context, provider),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PracticeProvider provider) {
    if (provider.isLoading && provider.questions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage.isNotEmpty && provider.questions.isEmpty) {
      return EmptyView(
        icon: Icons.error_outline,
        title: '题目加载失败',
        message: provider.errorMessage,
        actionLabel: '重试',
        onAction: _startPractice,
      );
    }
    if (provider.isFinished) {
      return _buildFinishedView(context, provider);
    }
    if (provider.questions.isEmpty) {
      return const EmptyView(
        icon: Icons.inbox_outlined,
        title: '暂无题目',
        message: '当前条件下没有可练习的题目',
      );
    }
    final question = provider.currentQuestion;
    if (question == null) {
      return const EmptyView(
        icon: Icons.inbox_outlined,
        title: '暂无题目',
        message: '当前条件下没有可练习的题目',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LinearProgressIndicator(value: provider.progress),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('第 ${provider.currentIndex + 1}/${provider.questions.length} 题'),
            const Spacer(),
            _buildTypeChip(question),
          ],
        ),
        const SizedBox(height: 16),
        Text(question.stem, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ...question.options.map((option) {
          return OptionTile(
            option: option,
            selected: provider.selectedOptions.contains(option.optionKey),
            isMultipleChoice: question.isMultipleChoice,
            enabled: !provider.isAnswered && !provider.isLoading,
            onTap: () {
              provider.selectOption(option.optionKey);
            },
          );
        }),
        if (provider.isAnswered && provider.lastAnswerCorrect != null)
          AnswerResultPanel(
            isCorrect: provider.lastAnswerCorrect!,
            question: question,
            selectedAnswer: provider.selectedAnswer,
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTypeChip(Question question) {
    final label = question.isSingleChoice
        ? '单选'
        : question.isMultipleChoice
            ? '多选'
            : '判断';
    return Chip(label: Text(label));
  }

  Widget _buildFinishedView(
    BuildContext context,
    PracticeProvider provider,
  ) {
    final accuracy = provider.answeredCount == 0
        ? 0.0
        : provider.correctCount / provider.answeredCount;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_outlined, size: 72),
            const SizedBox(height: 16),
            Text('本轮练习完成', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text('答题 ${provider.answeredCount} 题，答对 ${provider.correctCount} 题'),
            Text('正确率 ${(accuracy * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    PracticeProvider provider,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (provider.hasPrevious && !provider.isExamMode)
              OutlinedButton(
                onPressed: provider.isLoading
                    ? null
                    : () {
                        provider.previousQuestion();
                      },
                child: const Text('上一题'),
              ),
            if (provider.hasPrevious && !provider.isExamMode)
              const SizedBox(width: 12),
            Expanded(
              child: provider.isAnswered
                  ? FilledButton(
                      onPressed: provider.isLoading
                          ? null
                          : () {
                              if (provider.hasNext) {
                                provider.nextQuestion();
                              } else {
                                provider.finishExam();
                              }
                            },
                      child: Text(provider.hasNext ? '下一题' : '完成'),
                    )
                  : FilledButton(
                      onPressed: provider.canSubmit && !provider.isLoading
                          ? () {
                              provider.submitAnswer();
                            }
                          : null,
                      child: const Text('提交答案'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}