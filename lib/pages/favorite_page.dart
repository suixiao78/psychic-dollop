import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/practice_mode.dart';
import '../models/question.dart';
import '../models/quiz_arguments.dart';
import '../providers/favorite_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/question_images.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FavoriteProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('收藏夹')),
          floatingActionButton: provider.items.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.quiz,
                      arguments: const QuizArguments(
                        mode: PracticeMode.favoriteReview,
                        title: '收藏练习',
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('收藏练习'),
                ),
          body: _buildBody(context, provider),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, FavoriteProvider provider) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.items.isEmpty) {
      return const EmptyView(
        icon: Icons.favorite_border,
        title: '暂无收藏',
        message: '答题时可以点击右上角收藏按钮加入收藏',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.items.length,
      itemBuilder: (context, index) {
        final question = provider.items[index];
        return _FavoriteQuestionCard(
          question: question,
          onRemove: () {
            final questionId = question.id;
            if (questionId != null) {
              provider.toggle(questionId);
            }
          },
        );
      },
    );
  }
}

class _FavoriteQuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback onRemove;

  const _FavoriteQuestionCard({
    required this.question,
    required this.onRemove,
  });

  String _typeLabel(String type) {
    if (type == 'single') return '单选';
    if (type == 'multiple') return '多选';
    return '判断';
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
                  tooltip: '取消收藏',
                  onPressed: onRemove,
                  icon: const Icon(Icons.favorite, color: Colors.red),
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
              '正确答案：${question.correctAnswer}',
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