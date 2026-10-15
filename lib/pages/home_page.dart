import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/category_info.dart';
import '../models/practice_mode.dart';
import '../models/quiz_arguments.dart';
import '../providers/question_provider.dart';
import '../widgets/empty_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('国家电网刷题助手'),
        actions: [
          IconButton(
            tooltip: '错题本',
            icon: const Icon(Icons.error_outline),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.wrongBook);
            },
          ),
          IconButton(
            tooltip: '收藏',
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.favorites);
            },
          ),
          IconButton(
            tooltip: '统计',
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.stats);
            },
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.settings);
            },
          ),
        ],
      ),
      body: Consumer<QuestionProvider>(
        builder: (context, provider, child) {
          if (!provider.isReady && provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!provider.isReady && provider.errorMessage.isNotEmpty) {
            return EmptyView(
              icon: Icons.error_outline,
              title: '题库加载失败',
              message: provider.errorMessage,
              actionLabel: '重试',
              onAction: () {
                provider.init();
              },
            );
          }
          return RefreshIndicator(
            onRefresh: provider.init,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('考纲层次', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildLevelSelector(context, provider),
                const SizedBox(height: 20),
                _buildExamCard(context, provider),
                const SizedBox(height: 24),
                Text('科目与章节', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (provider.subjects.isEmpty)
                  const SizedBox(
                    height: 300,
                    child: EmptyView(
                      icon: Icons.library_books_outlined,
                      title: '暂无题目',
                      message: '请检查 assets/questions.json 是否已正确导入',
                    ),
                  )
                else
                  ...provider.subjects.map(
                    (SubjectInfo subject) => _buildSubjectCard(
                      context,
                      provider,
                      subject,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelSelector(BuildContext context, QuestionProvider provider) {
    const levels = <String>['专科', '本科', '硕士'];
    return Wrap(
      spacing: 8,
      children: levels.map((level) {
        return ChoiceChip(
          label: Text(level),
          selected: provider.selectedExamLevel == level,
          onSelected: (_) {
            provider.setExamLevel(level);
          },
        );
      }).toList(),
    );
  }

  Widget _buildExamCard(BuildContext context, QuestionProvider provider) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: Text('模拟考试  ${provider.selectedExamLevel}'),
        subtitle: const Text('随机抽取 100 题进行模拟测试'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _openQuiz(
            context,
            PracticeMode.exam,
            title: '模拟考试  ${provider.selectedExamLevel}',
            count: 100,
          );
        },
      ),
    );
  }

  Widget _buildSubjectCard(
    BuildContext context,
    QuestionProvider provider,
    SubjectInfo subject,
  ) {
    final selected = provider.selectedSubjectId == subject.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(subject.name.isNotEmpty ? subject.name[0] : '科'),
            ),
            title: Text(subject.name),
            subtitle: Text('${subject.questionCount} 题'),
            trailing: Icon(selected ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              provider.selectSubject(subject.id);
            },
          ),
          if (selected) ...[
            const Divider(height: 1),
            if (provider.isLoading && provider.chapters.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.chapters.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('该科目下暂无章节'),
              )
            else
              ...provider.chapters.map(
                (ChapterInfo chapter) => _buildChapterTile(
                  context,
                  subject,
                  chapter,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterTile(
    BuildContext context,
    SubjectInfo subject,
    ChapterInfo chapter,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chapter.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('${chapter.questionCount} 题',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _openQuiz(
                      context,
                      PracticeMode.sequence,
                      subject: subject,
                      chapter: chapter,
                      count: null,
                    );
                  },
                  child: const Text('顺序练习'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () {
                    _openQuiz(
                      context,
                      PracticeMode.random,
                      subject: subject,
                      chapter: chapter,
                      count: null,
                    );
                  },
                  child: const Text('随机练习'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openQuiz(
    BuildContext context,
    PracticeMode mode, {
    SubjectInfo? subject,
    ChapterInfo? chapter,
    String? title,
    int? count,
  }) {
    final provider = context.read<QuestionProvider>();
    final finalTitle = title ??
        (subject != null && chapter != null
            ? '${subject.name}  ${chapter.name}'
            : '练习');
    Navigator.of(context).pushNamed(
      AppRoutes.quiz,
      arguments: QuizArguments(
        mode: mode,
        title: finalTitle,
        examLevel: provider.selectedExamLevel,
        subjectId: subject?.id,
        chapterId: chapter?.id,
        count: count,
      ),
    );
  }
}