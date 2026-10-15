import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/practice_mode.dart';
import '../models/question.dart';
import '../models/quiz_arguments.dart';
import '../providers/wrong_book_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/question_images.dart';

class WrongBookPage extends StatefulWidget {
  const WrongBookPage({super.key});

  @override
  State<WrongBookPage> createState() => _WrongBookPageState();
}

class _WrongBookPageState extends State<WrongBookPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WrongBookProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WrongBookProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('错题本')),
          floatingActionButton: provider.items.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.quiz,
                      arguments: const QuizArguments(
                        mode: PracticeMode.wrongReview,
                        title: '错题重做',
                        count: 100,
                      ),
                    );
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('错题重做'),
                ),
          body: _buildBody(context, provider),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WrongBookProvider provider) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.items.isEmpty) {
      return const EmptyView(
        icon: Icons.inbox_outlined,
        title: '暂无错题',
        message: '答错的题目会自动收集到这里',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.items.length,
      itemBuilder: (context, index) {
        final question = provider.items[index];
        return _WrongQuestionCard(
          question: question,
          onRemove: () {
            final questionId = question.id;
            if (questionId != null) {
              provider.remove(questionId);
            }
          },
        );
      },
    );
  }
}

class _WrongQuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback onRemove;

  const _WrongQuestionCard({
    required this.question,
    required this.onRemove,
  });

  String _typeLabel(String type) {
    if (type == 'single') return '单选';
    if (type == 'multiple') return '多选';
    return '判断';
  }

  String _answerText() {
    final optionMap = <String, String>{
      for (final option in question.options) option.optionKey: option.content,
    };
    return question.correctAnswer.split('').map((key) {
      final content = optionMap[key] ?? '';
      return content.isEmpty ? key : '$key. $content';
    }).join('；');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(_typeLabel(question.questionType))),
                const Spacer(),
                IconButton(
                  tooltip: '移除',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(question.stem, style: Theme.of(context).textTheme.titleMedium),
            if (question.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              QuestionImages(images: question.images, height: 160),
            ] else if (question.sourceImage.isNotEmpty) ...[
              const SizedBox(height: 8),
              SourceImageButton(sourceImage: question.sourceImage, label: '查看原图'),
            ],
            const SizedBox(height: 8),
            Text(
              '正确答案：${_answerText()}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(question.explanation),
            ],
          ],
        ),
      ),
    );
  }
}