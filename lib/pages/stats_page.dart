import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_stat.dart';
import '../providers/stats_provider.dart';
import '../widgets/stat_card.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StatsProvider>().load();
      }
    });
  }

  String _percent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String _dateLabel(String date) {
    if (date.length >= 10) {
      return date.substring(5);
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StatsProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('学习统计')),
          body: provider.isLoading &&
                  provider.totalAnswered == 0 &&
                  provider.recentStats.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: provider.load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('今日进度',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: provider.todayProgress,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${provider.today.answeredCount}/${provider.today.targetCount} 题',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          StatCard(
                            title: '今日做题',
                            value: '${provider.today.answeredCount}',
                            subtitle: '答对 ${provider.today.correctCount}',
                            icon: Icons.today,
                          ),
                          StatCard(
                            title: '今日正确率',
                            value: _percent(provider.today.accuracy),
                            subtitle: '目标 ${provider.today.targetCount} 题',
                            icon: Icons.percent,
                          ),
                          StatCard(
                            title: '总做题数',
                            value: '${provider.totalAnswered}',
                            subtitle: '累计答题',
                            icon: Icons.list_alt,
                          ),
                          StatCard(
                            title: '总正确率',
                            value: _percent(provider.accuracy),
                            subtitle: '答对 ${provider.totalCorrect}',
                            icon: Icons.verified,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('近 7 天',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (provider.recentStats.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('暂无记录')),
                        )
                      else
                        ...provider.recentStats.map((StudyStat stat) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(_dateLabel(stat.statDate)),
                              subtitle: Text(
                                '做题 ${stat.answeredCount} 题，正确 ${stat.correctCount} 题',
                              ),
                              trailing: Text(
                                _percent(stat.accuracy),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
        );
      },
    );
  }
}