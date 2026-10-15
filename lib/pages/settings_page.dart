import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../providers/stats_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StatsProvider>().load();
      }
    });
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _appVersion = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StatsProvider>(
      builder: (context, provider, child) {
        final target = provider.today.targetCount;
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('每日刷题目标'),
                  subtitle: Text('当前目标：$target 题'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '减少',
                        onPressed: target > 5
                            ? () {
                                provider.setDailyTarget(target - 5);
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$target',
                          style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        tooltip: '增加',
                        onPressed: target < 100
                            ? () {
                                provider.setDailyTarget(target + 5);
                              }
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.storage_outlined),
                      title: Text('数据存储'),
                      subtitle: Text('答题记录、错题和收藏均保存在本机 SQLite'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.download_outlined),
                      title: Text('题库来源'),
                      subtitle: Text('assets/questions.json'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.wifi_off_outlined),
                      title: Text('离线模式'),
                      subtitle: Text('不需要登录，不需要联网'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于'),
                  subtitle: Text(
                    '国家电网刷题助手 v${_appVersion.isEmpty ? '...' : _appVersion}',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}