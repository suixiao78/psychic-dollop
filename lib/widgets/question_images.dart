import 'package:flutter/material.dart';

class QuestionImages extends StatelessWidget {
  final List<String> images;
  final double height;

  const QuestionImages({
    super.key,
    required this.images,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: images.map((String path) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _showFullScreen(context, path);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                path,
                height: height,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: height,
                    alignment: Alignment.center,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '图片加载失败：$path',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showFullScreen(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Size size = MediaQuery.of(dialogContext).size;
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: size.width,
            height: size.height * 0.8,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Image.asset(
                      path,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Text('图片加载失败'),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: '关闭',
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}